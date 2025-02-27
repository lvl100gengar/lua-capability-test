#!/usr/bin/env python3

import argparse
import subprocess
import time
import os
import json
from typing import List, Dict
import matplotlib.pyplot as plt

def generate_test_file(config_path: str, output_path: str, size_mb: float) -> None:
    """Generate a test file of the specified size."""
    subprocess.run(['python3', 'generate_test_file.py', config_path, output_path, str(size_mb)],
                  check=True)

def run_validation(file_path: str, config_path: str) -> float:
    """Run the Lua validator and return the execution time in seconds."""
    start_time = time.time()
    result = subprocess.run(['lua', 'validate_file.lua', file_path, config_path],
                          capture_output=True, text=True)
    end_time = time.time()
    
    if result.returncode != 0:
        raise RuntimeError(f"Validation failed: {result.stderr}")
    
    return end_time - start_time

def run_benchmark(config_path: str, sizes_mb: List[float], runs_per_size: int = 3) -> Dict:
    """Run benchmarks for different file sizes."""
    results = {
        'sizes_mb': sizes_mb,
        'times': [],
        'throughputs': []  # MB/s
    }
    
    print("\nRunning benchmarks...")
    print(f"{'Size (MB)':>10} {'Time (s)':>10} {'Throughput (MB/s)':>15}")
    print("-" * 35)
    
    for size_mb in sizes_mb:
        # Generate test file
        test_file = f'benchmark_test_{size_mb}MB.txt'
        generate_test_file(config_path, test_file, size_mb)
        
        # Run multiple times and take average
        times = []
        for _ in range(runs_per_size):
            try:
                execution_time = run_validation(test_file, config_path)
                times.append(execution_time)
            except RuntimeError as e:
                print(f"Error during validation: {e}")
                continue
        
        if times:
            avg_time = sum(times) / len(times)
            throughput = size_mb / avg_time
            results['times'].append(avg_time)
            results['throughputs'].append(throughput)
            
            print(f"{size_mb:10.1f} {avg_time:10.3f} {throughput:15.2f}")
        
        # Clean up test file
        os.remove(test_file)
    
    return results

def plot_results(results: Dict, output_prefix: str) -> None:
    """Generate plots for the benchmark results."""
    # Time vs Size plot
    plt.figure(figsize=(10, 6))
    plt.plot(results['sizes_mb'], results['times'], 'b-o')
    plt.xlabel('File Size (MB)')
    plt.ylabel('Validation Time (s)')
    plt.title('Validation Time vs File Size')
    plt.grid(True)
    plt.savefig(f'{output_prefix}_time.png')
    plt.close()
    
    # Throughput vs Size plot
    plt.figure(figsize=(10, 6))
    plt.plot(results['sizes_mb'], results['throughputs'], 'g-o')
    plt.xlabel('File Size (MB)')
    plt.ylabel('Throughput (MB/s)')
    plt.title('Validation Throughput vs File Size')
    plt.grid(True)
    plt.savefig(f'{output_prefix}_throughput.png')
    plt.close()

def main():
    parser = argparse.ArgumentParser(description='Benchmark Lua validator performance')
    parser.add_argument('config', help='Path to Lua configuration file')
    parser.add_argument('--sizes', type=float, nargs='+', default=[0.1, 1, 5, 10, 50, 100],
                        help='File sizes to test in MB')
    parser.add_argument('--runs', type=int, default=3,
                        help='Number of runs per file size')
    parser.add_argument('--output', default='benchmark_results',
                        help='Prefix for output files')
    
    args = parser.parse_args()
    
    # Run benchmarks
    results = run_benchmark(args.config, args.sizes, args.runs)
    
    # Save results
    with open(f'{args.output}.json', 'w') as f:
        json.dump(results, f, indent=2)
    
    # Generate plots
    plot_results(results, args.output)
    
    print(f"\nResults saved to {args.output}.json")
    print(f"Plots saved as {args.output}_time.png and {args.output}_throughput.png")

if __name__ == '__main__':
    main() 