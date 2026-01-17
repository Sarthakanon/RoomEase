from setuptools import setup, find_packages

setup(
    name="roomease-ml-pipeline",
    version="0.1.0",
    description="ML pipeline for RoomEase spending analytics",
    author="RoomEase Team",
    packages=find_packages(),
    install_requires=[
        "pandas>=2.0.0",
        "numpy>=1.24.0",
        "scikit-learn>=1.3.0",
        "tensorflow>=2.15.0",
        "kagglehub>=0.2.0",
    ],
    python_requires=">=3.10",
)
