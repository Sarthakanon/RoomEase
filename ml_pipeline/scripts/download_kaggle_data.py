"""Download financial transactions dataset from Kaggle."""

import kagglehub
import shutil
from pathlib import Path

def download_dataset():
    """Download the financial transactions dataset."""
    print("Downloading financial transactions dataset from Kaggle...")
    
    # Download latest version
    path = kagglehub.dataset_download(
        "artemkabseu/financial-transactions-dataset-expenses-and-income"
    )
    
    print(f"Dataset downloaded to: {path}")
    
    # Copy to our data directory
    data_dir = Path(__file__).parent.parent / "data" / "raw"
    data_dir.mkdir(parents=True, exist_ok=True)
    
    # Copy all files from download path to our data directory
    source_path = Path(path)
    for file in source_path.glob("*"):
        if file.is_file():
            dest = data_dir / file.name
            shutil.copy2(file, dest)
            print(f"Copied {file.name} to {dest}")
    
    print(f"\nDataset files available in: {data_dir}")
    return data_dir

if __name__ == "__main__":
    download_dataset()
