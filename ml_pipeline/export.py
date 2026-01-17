"""Model export utilities for TFLite and ONNX formats.

This module provides functionality to export trained scikit-learn models
to formats suitable for deployment:
- TFLite: For mobile inference (Flutter app)
- ONNX: For cross-platform inference (Go backend)
"""

import pickle
import json
import numpy as np
from pathlib import Path
from typing import Dict, Optional, Union
from datetime import datetime
import warnings


def export_to_onnx(
    model_path: str,
    output_path: str,
    model_name: str,
    initial_types: Optional[list] = None
) -> str:
    """
    Export a scikit-learn model to ONNX format.
    
    Args:
        model_path: Path to the pickled model file
        output_path: Directory to save ONNX model
        model_name: Name for the exported model
        initial_types: List of (name, type) tuples for input specification
    
    Returns:
        Path to the exported ONNX model
    """
    try:
        from skl2onnx import convert_sklearn
        from skl2onnx.common.data_types import FloatTensorType
    except ImportError:
        raise ImportError(
            "skl2onnx is required for ONNX export. "
            "Install with: pip install skl2onnx onnx onnxruntime"
        )
    
    print(f"Exporting {model_name} to ONNX format...")
    
    # Load the model
    with open(model_path, 'rb') as f:
        model = pickle.load(f)
    
    # Load metadata to get feature count
    metadata_path = Path(model_path).parent / f"{Path(model_path).stem}_metadata.json"
    if metadata_path.exists():
        with open(metadata_path, 'r') as f:
            metadata = json.load(f)
            n_features = len(metadata.get('feature_names', []))
    else:
        # Try to infer from model
        if hasattr(model, 'n_features_in_'):
            n_features = model.n_features_in_
        else:
            raise ValueError("Cannot determine number of features. Provide metadata file.")
    
    # Define initial types if not provided
    if initial_types is None:
        initial_types = [('float_input', FloatTensorType([None, n_features]))]
    
    # Convert to ONNX
    try:
        # Special handling for IsolationForest
        if hasattr(model, '__class__') and 'IsolationForest' in model.__class__.__name__:
            onnx_model = convert_sklearn(
                model,
                initial_types=initial_types,
                target_opset={'': 12, 'ai.onnx.ml': 3},
                options={id(model): {'score_samples': False}}
            )
        else:
            onnx_model = convert_sklearn(
                model,
                initial_types=initial_types,
                target_opset=12  # Compatible with most ONNX runtimes
            )
    except Exception as e:
        print(f"Warning: Direct conversion failed: {e}")
        print("Attempting conversion with options...")
        
        # Try with options for better compatibility
        from skl2onnx.common.data_types import FloatTensorType
        onnx_model = convert_sklearn(
            model,
            initial_types=initial_types,
            target_opset={'': 12, 'ai.onnx.ml': 3},
            options={id(model): {'zipmap': False}}
        )
    
    # Save ONNX model
    output_dir = Path(output_path)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    onnx_file = output_dir / f"{model_name}.onnx"
    
    with open(onnx_file, 'wb') as f:
        f.write(onnx_model.SerializeToString())
    
    print(f"✓ ONNX model saved to {onnx_file}")
    
    # Save export metadata
    export_metadata = {
        'model_name': model_name,
        'format': 'onnx',
        'exported_at': datetime.now().isoformat(),
        'n_features': n_features,
        'source_model': str(model_path),
        'opset_version': 12
    }
    
    metadata_file = output_dir / f"{model_name}_onnx_metadata.json"
    with open(metadata_file, 'w') as f:
        json.dump(export_metadata, f, indent=2)
    
    print(f"✓ Export metadata saved to {metadata_file}")
    
    return str(onnx_file)


def export_to_tflite(
    model_path: str,
    output_path: str,
    model_name: str,
    representative_dataset: Optional[np.ndarray] = None
) -> str:
    """
    Export a model to TensorFlow Lite format.
    
    Note: This requires converting through ONNX first, then to TFLite.
    For scikit-learn models, ONNX is the recommended format for mobile.
    
    Args:
        model_path: Path to the pickled model file
        output_path: Directory to save TFLite model
        model_name: Name for the exported model
        representative_dataset: Sample data for quantization (optional)
    
    Returns:
        Path to the exported TFLite model
    """
    print(f"\nNote: TFLite export for scikit-learn models is experimental.")
    print("For production use, consider using ONNX format with ONNX Runtime Mobile.")
    print("Alternatively, retrain the model using TensorFlow/Keras.\n")
    
    try:
        import tensorflow as tf
        import onnx
        from onnx_tf.backend import prepare
    except ImportError:
        raise ImportError(
            "TensorFlow and onnx-tf are required for TFLite export. "
            "Install with: pip install tensorflow onnx onnx-tf"
        )
    
    # First export to ONNX
    temp_onnx_path = Path(output_path) / "temp"
    onnx_file = export_to_onnx(model_path, str(temp_onnx_path), f"{model_name}_temp")
    
    print(f"\nConverting ONNX to TFLite...")
    
    # Load ONNX model
    onnx_model = onnx.load(onnx_file)
    
    # Convert ONNX to TensorFlow
    tf_rep = prepare(onnx_model)
    
    # Export to SavedModel format
    saved_model_path = Path(output_path) / f"{model_name}_saved_model"
    tf_rep.export_graph(str(saved_model_path))
    
    # Convert to TFLite
    converter = tf.lite.TFLiteConverter.from_saved_model(str(saved_model_path))
    
    # Apply optimizations
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    
    # Use representative dataset for quantization if provided
    if representative_dataset is not None:
        def representative_data_gen():
            for sample in representative_dataset:
                yield [sample.astype(np.float32).reshape(1, -1)]
        
        converter.representative_dataset = representative_data_gen
    
    # Convert
    tflite_model = converter.convert()
    
    # Save TFLite model
    output_dir = Path(output_path)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    tflite_file = output_dir / f"{model_name}.tflite"
    
    with open(tflite_file, 'wb') as f:
        f.write(tflite_model)
    
    print(f"✓ TFLite model saved to {tflite_file}")
    
    # Save export metadata
    export_metadata = {
        'model_name': model_name,
        'format': 'tflite',
        'exported_at': datetime.now().isoformat(),
        'source_model': str(model_path),
        'optimizations': ['DEFAULT'],
        'quantized': representative_dataset is not None
    }
    
    metadata_file = output_dir / f"{model_name}_tflite_metadata.json"
    with open(metadata_file, 'w') as f:
        json.dump(export_metadata, f, indent=2)
    
    print(f"✓ Export metadata saved to {metadata_file}")
    
    # Clean up temporary files
    import shutil
    if temp_onnx_path.exists():
        shutil.rmtree(temp_onnx_path)
    if saved_model_path.exists():
        shutil.rmtree(saved_model_path)
    
    return str(tflite_file)


def export_all_models(
    models_dir: str,
    output_dir: str,
    formats: list = ['onnx']
) -> Dict[str, Dict[str, str]]:
    """
    Export all trained models in the models directory.
    
    Args:
        models_dir: Directory containing trained models
        output_dir: Directory to save exported models
        formats: List of formats to export to ('onnx', 'tflite')
    
    Returns:
        Dictionary mapping model names to exported file paths
    """
    models_path = Path(models_dir)
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)
    
    exported_models = {}
    
    # Find all model files
    model_files = {
        'spending_predictor': models_path / 'spending_predictor.pkl',
        'pattern_classifier': models_path / 'pattern_classifier.pkl',
        'anomaly_detector': models_path / 'anomaly_detector.pkl'
    }
    
    print("=" * 70)
    print("MODEL EXPORT PIPELINE")
    print("=" * 70)
    
    for model_name, model_file in model_files.items():
        if not model_file.exists():
            print(f"\n⚠ Skipping {model_name}: Model file not found")
            continue
        
        print(f"\n{'='*70}")
        print(f"Exporting {model_name}")
        print(f"{'='*70}")
        
        exported_models[model_name] = {}
        
        # Export to each requested format
        for fmt in formats:
            try:
                if fmt == 'onnx':
                    onnx_path = export_to_onnx(
                        str(model_file),
                        str(output_path / 'onnx'),
                        model_name
                    )
                    exported_models[model_name]['onnx'] = onnx_path
                
                elif fmt == 'tflite':
                    # Load some sample data for quantization
                    data_dir = models_path.parent / 'data' / 'splits'
                    test_file = data_dir / 'synthetic_expenses_test.csv'
                    
                    representative_data = None
                    if test_file.exists():
                        import pandas as pd
                        test_df = pd.read_csv(test_file)
                        
                        # Get appropriate feature engineer based on model
                        if model_name == 'spending_predictor':
                            from preprocessing import ExpenseFeatureEngineer
                            engineer = ExpenseFeatureEngineer()
                            engineer.fit(test_df)
                            X_sample = engineer.transform(test_df.head(100))
                            representative_data = X_sample.values
                        
                    tflite_path = export_to_tflite(
                        str(model_file),
                        str(output_path / 'tflite'),
                        model_name,
                        representative_data
                    )
                    exported_models[model_name]['tflite'] = tflite_path
                
                else:
                    print(f"⚠ Unknown format: {fmt}")
            
            except Exception as e:
                print(f"✗ Failed to export {model_name} to {fmt}: {e}")
                import traceback
                traceback.print_exc()
    
    print("\n" + "=" * 70)
    print("EXPORT COMPLETE!")
    print("=" * 70)
    
    # Print summary
    print("\nExported Models:")
    for model_name, paths in exported_models.items():
        print(f"\n  {model_name}:")
        for fmt, path in paths.items():
            print(f"    {fmt.upper()}: {path}")
    
    return exported_models


def verify_onnx_model(onnx_path: str, test_input: Optional[np.ndarray] = None) -> bool:
    """
    Verify that an ONNX model can be loaded and used for inference.
    
    Args:
        onnx_path: Path to ONNX model file
        test_input: Optional test input for inference verification
    
    Returns:
        True if model is valid and can perform inference
    """
    try:
        import onnx
        import onnxruntime as ort
    except ImportError:
        print("⚠ onnx and onnxruntime required for verification")
        return False
    
    print(f"\nVerifying ONNX model: {onnx_path}")
    
    try:
        # Load and check model
        onnx_model = onnx.load(onnx_path)
        onnx.checker.check_model(onnx_model)
        print("✓ Model structure is valid")
        
        # Create inference session
        session = ort.InferenceSession(onnx_path)
        
        # Get input/output info
        input_name = session.get_inputs()[0].name
        input_shape = session.get_inputs()[0].shape
        output_name = session.get_outputs()[0].name
        
        print(f"✓ Input: {input_name}, shape: {input_shape}")
        print(f"✓ Output: {output_name}")
        
        # Test inference if test input provided
        if test_input is not None:
            # Ensure correct shape
            if len(test_input.shape) == 1:
                test_input = test_input.reshape(1, -1)
            
            result = session.run([output_name], {input_name: test_input.astype(np.float32)})
            print(f"✓ Inference successful, output shape: {result[0].shape}")
        
        return True
    
    except Exception as e:
        print(f"✗ Verification failed: {e}")
        return False


if __name__ == '__main__':
    """Export all trained models to ONNX format."""
    from pathlib import Path
    
    # Paths
    base_dir = Path(__file__).parent
    models_dir = base_dir / 'models'
    output_dir = base_dir / 'models' / 'exported'
    
    # Check if models exist
    if not models_dir.exists():
        print(f"Error: Models directory not found at {models_dir}")
        print("Please train the models first.")
        exit(1)
    
    # Export models to ONNX (recommended for production)
    exported = export_all_models(
        str(models_dir),
        str(output_dir),
        formats=['onnx']  # Use ONNX for both mobile and backend
    )
    
    # Verify exported models
    print("\n" + "=" * 70)
    print("VERIFYING EXPORTED MODELS")
    print("=" * 70)
    
    for model_name, paths in exported.items():
        if 'onnx' in paths:
            # Create dummy test input
            metadata_file = models_dir / f"{model_name}_metadata.json"
            if metadata_file.exists():
                with open(metadata_file, 'r') as f:
                    metadata = json.load(f)
                    n_features = len(metadata.get('feature_names', []))
                    test_input = np.random.randn(1, n_features)
                    verify_onnx_model(paths['onnx'], test_input)
