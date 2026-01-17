"""Model versioning utilities for ML pipeline.

This module provides functionality to:
- Generate semantic version numbers for models
- Track model lineage and history
- Compare model performance across versions
- Manage model registry
"""

import json
import hashlib
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from datetime import datetime
import shutil


class ModelVersion:
    """Represents a specific version of a trained model."""
    
    def __init__(
        self,
        model_name: str,
        version: str,
        trained_at: str,
        metrics: Dict[str, float],
        model_path: str,
        metadata_path: str
    ):
        self.model_name = model_name
        self.version = version
        self.trained_at = trained_at
        self.metrics = metrics
        self.model_path = model_path
        self.metadata_path = metadata_path
    
    def to_dict(self) -> Dict:
        """Convert to dictionary for serialization."""
        return {
            'model_name': self.model_name,
            'version': self.version,
            'trained_at': self.trained_at,
            'metrics': self.metrics,
            'model_path': self.model_path,
            'metadata_path': self.metadata_path
        }
    
    @classmethod
    def from_dict(cls, data: Dict) -> 'ModelVersion':
        """Create from dictionary."""
        return cls(
            model_name=data['model_name'],
            version=data['version'],
            trained_at=data['trained_at'],
            metrics=data['metrics'],
            model_path=data['model_path'],
            metadata_path=data['metadata_path']
        )


class ModelRegistry:
    """
    Manages model versions and provides version control functionality.
    
    The registry maintains a history of all trained models with their
    performance metrics, allowing for version comparison and rollback.
    """
    
    def __init__(self, registry_path: str):
        """
        Initialize the model registry.
        
        Args:
            registry_path: Path to the registry JSON file
        """
        self.registry_path = Path(registry_path)
        self.registry_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Load existing registry or create new
        if self.registry_path.exists():
            with open(self.registry_path, 'r') as f:
                data = json.load(f)
                self.models = {
                    name: [ModelVersion.from_dict(v) for v in versions]
                    for name, versions in data.items()
                }
        else:
            self.models = {}
    
    def save(self):
        """Save registry to disk."""
        data = {
            name: [v.to_dict() for v in versions]
            for name, versions in self.models.items()
        }
        
        with open(self.registry_path, 'w') as f:
            json.dump(data, f, indent=2)
    
    def register_model(
        self,
        model_name: str,
        model_path: str,
        metadata_path: str,
        version: Optional[str] = None
    ) -> ModelVersion:
        """
        Register a new model version.
        
        Args:
            model_name: Name of the model
            model_path: Path to the model file
            metadata_path: Path to the metadata file
            version: Optional version string (auto-generated if not provided)
        
        Returns:
            ModelVersion object
        """
        # Load metadata
        with open(metadata_path, 'r') as f:
            metadata = json.load(f)
        
        # Extract metrics
        metrics = metadata.get('training_metrics', {})
        trained_at = metadata.get('trained_at', datetime.now().isoformat())
        
        # Generate version if not provided
        if version is None:
            version = self._generate_version(model_name, trained_at)
        
        # Create model version
        model_version = ModelVersion(
            model_name=model_name,
            version=version,
            trained_at=trained_at,
            metrics=metrics,
            model_path=str(model_path),
            metadata_path=str(metadata_path)
        )
        
        # Add to registry
        if model_name not in self.models:
            self.models[model_name] = []
        
        self.models[model_name].append(model_version)
        
        # Save registry
        self.save()
        
        print(f"✓ Registered {model_name} version {version}")
        
        return model_version
    
    def _generate_version(self, model_name: str, trained_at: str) -> str:
        """
        Generate a semantic version number.
        
        Format: v{major}.{minor}.{patch}
        - major: Incremented for breaking changes
        - minor: Incremented for new features
        - patch: Incremented for bug fixes and improvements
        
        For now, we use timestamp-based versioning: v{YYYYMMDD}.{HHMMSS}
        """
        dt = datetime.fromisoformat(trained_at)
        return f"v{dt.strftime('%Y%m%d')}.{dt.strftime('%H%M%S')}"
    
    def get_latest_version(self, model_name: str) -> Optional[ModelVersion]:
        """
        Get the latest version of a model.
        
        Args:
            model_name: Name of the model
        
        Returns:
            Latest ModelVersion or None if model not found
        """
        if model_name not in self.models or not self.models[model_name]:
            return None
        
        # Sort by trained_at timestamp
        versions = sorted(
            self.models[model_name],
            key=lambda v: v.trained_at,
            reverse=True
        )
        
        return versions[0]
    
    def get_version(self, model_name: str, version: str) -> Optional[ModelVersion]:
        """
        Get a specific version of a model.
        
        Args:
            model_name: Name of the model
            version: Version string
        
        Returns:
            ModelVersion or None if not found
        """
        if model_name not in self.models:
            return None
        
        for v in self.models[model_name]:
            if v.version == version:
                return v
        
        return None
    
    def list_versions(self, model_name: str) -> List[ModelVersion]:
        """
        List all versions of a model.
        
        Args:
            model_name: Name of the model
        
        Returns:
            List of ModelVersion objects, sorted by date (newest first)
        """
        if model_name not in self.models:
            return []
        
        return sorted(
            self.models[model_name],
            key=lambda v: v.trained_at,
            reverse=True
        )
    
    def compare_versions(
        self,
        model_name: str,
        version1: str,
        version2: str,
        metric: str = 'test_mae'
    ) -> Dict:
        """
        Compare two versions of a model.
        
        Args:
            model_name: Name of the model
            version1: First version to compare
            version2: Second version to compare
            metric: Metric to compare (default: 'test_mae')
        
        Returns:
            Dictionary with comparison results
        """
        v1 = self.get_version(model_name, version1)
        v2 = self.get_version(model_name, version2)
        
        if v1 is None or v2 is None:
            raise ValueError(f"Version not found for {model_name}")
        
        metric1 = v1.metrics.get(metric, None)
        metric2 = v2.metrics.get(metric, None)
        
        if metric1 is None or metric2 is None:
            raise ValueError(f"Metric '{metric}' not found in model metrics")
        
        # For error metrics (MAE, RMSE), lower is better
        # For accuracy/R2, higher is better
        is_error_metric = metric.lower() in ['mae', 'rmse', 'mse']
        
        if is_error_metric:
            improvement = ((metric1 - metric2) / metric1) * 100
            better_version = version2 if metric2 < metric1 else version1
        else:
            improvement = ((metric2 - metric1) / metric1) * 100
            better_version = version2 if metric2 > metric1 else version1
        
        return {
            'model_name': model_name,
            'version1': version1,
            'version2': version2,
            'metric': metric,
            'value1': metric1,
            'value2': metric2,
            'improvement_pct': improvement,
            'better_version': better_version
        }
    
    def get_best_version(
        self,
        model_name: str,
        metric: str = 'test_mae',
        minimize: bool = True
    ) -> Optional[ModelVersion]:
        """
        Get the best performing version based on a metric.
        
        Args:
            model_name: Name of the model
            metric: Metric to optimize
            minimize: True if lower is better (e.g., MAE), False if higher is better (e.g., accuracy)
        
        Returns:
            Best ModelVersion or None if model not found
        """
        versions = self.list_versions(model_name)
        
        if not versions:
            return None
        
        # Filter versions that have the metric
        versions_with_metric = [
            v for v in versions
            if metric in v.metrics
        ]
        
        if not versions_with_metric:
            return None
        
        # Sort by metric
        best = sorted(
            versions_with_metric,
            key=lambda v: v.metrics[metric],
            reverse=not minimize
        )[0]
        
        return best
    
    def archive_version(
        self,
        model_name: str,
        version: str,
        archive_dir: str
    ):
        """
        Archive a specific model version.
        
        Args:
            model_name: Name of the model
            version: Version to archive
            archive_dir: Directory to store archived models
        """
        model_version = self.get_version(model_name, version)
        
        if model_version is None:
            raise ValueError(f"Version {version} not found for {model_name}")
        
        archive_path = Path(archive_dir) / model_name / version
        archive_path.mkdir(parents=True, exist_ok=True)
        
        # Copy model and metadata files
        shutil.copy(model_version.model_path, archive_path)
        shutil.copy(model_version.metadata_path, archive_path)
        
        print(f"✓ Archived {model_name} {version} to {archive_path}")
    
    def print_summary(self):
        """Print a summary of all registered models."""
        print("=" * 70)
        print("MODEL REGISTRY SUMMARY")
        print("=" * 70)
        
        for model_name in sorted(self.models.keys()):
            versions = self.list_versions(model_name)
            print(f"\n{model_name}:")
            print(f"  Total versions: {len(versions)}")
            
            if versions:
                latest = versions[0]
                print(f"  Latest version: {latest.version}")
                print(f"  Trained at: {latest.trained_at}")
                print(f"  Metrics:")
                for metric, value in latest.metrics.items():
                    print(f"    {metric}: {value:.4f}")


def version_all_models(models_dir: str, registry_path: str):
    """
    Register all models in a directory.
    
    Args:
        models_dir: Directory containing trained models
        registry_path: Path to the registry file
    """
    registry = ModelRegistry(registry_path)
    
    models_path = Path(models_dir)
    
    # Find all model files
    model_files = {
        'spending_predictor': models_path / 'spending_predictor.pkl',
        'pattern_classifier': models_path / 'pattern_classifier.pkl',
        'anomaly_detector': models_path / 'anomaly_detector.pkl'
    }
    
    print("=" * 70)
    print("MODEL VERSIONING")
    print("=" * 70)
    
    for model_name, model_file in model_files.items():
        if not model_file.exists():
            print(f"\n⚠ Skipping {model_name}: Model file not found")
            continue
        
        metadata_file = model_file.parent / f"{model_name}_metadata.json"
        
        if not metadata_file.exists():
            print(f"\n⚠ Skipping {model_name}: Metadata file not found")
            continue
        
        print(f"\nRegistering {model_name}...")
        registry.register_model(
            model_name=model_name,
            model_path=str(model_file),
            metadata_path=str(metadata_file)
        )
    
    print("\n" + "=" * 70)
    registry.print_summary()
    print("=" * 70)
    
    return registry


if __name__ == '__main__':
    """Version all trained models."""
    from pathlib import Path
    
    # Paths
    base_dir = Path(__file__).parent
    models_dir = base_dir / 'models'
    registry_path = base_dir / 'models' / 'model_registry.json'
    
    # Check if models exist
    if not models_dir.exists():
        print(f"Error: Models directory not found at {models_dir}")
        print("Please train the models first.")
        exit(1)
    
    # Version all models
    registry = version_all_models(str(models_dir), str(registry_path))
    
    # Example: Get best version of spending predictor
    print("\n" + "=" * 70)
    print("BEST MODEL VERSIONS")
    print("=" * 70)
    
    for model_name in ['spending_predictor', 'pattern_classifier', 'anomaly_detector']:
        # Try different metrics based on model type
        if model_name == 'spending_predictor':
            metric = 'val_mae'
            minimize = True
        elif model_name == 'pattern_classifier':
            metric = 'val_f1'
            minimize = False
        else:  # anomaly_detector
            metric = 'train_f1'
            minimize = False
        
        best = registry.get_best_version(model_name, metric=metric, minimize=minimize)
        
        if best:
            print(f"\n{model_name}:")
            print(f"  Best version: {best.version}")
            print(f"  Metric ({metric}): {best.metrics.get(metric, 'N/A')}")
