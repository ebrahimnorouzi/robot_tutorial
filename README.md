# ROBOT Demo (Docker)

This repo demonstrates many ROBOT commands using a reproducible Docker image.

- Base image: `obolibrary/odkfull:1.9.7` (includes ROBOT 1.9.7)
- Scripts:
  - `dataset.sh` — creates example ontologies, CSV templates, SPARQL, and Python files
  - `run_demo.sh` — runs a showcase of ROBOT commands and produces outputs in `results/`

## Quick Start

```bash
# Clone this repo, then:
docker build -t robot-demo .

# Run inside a container and keep outputs in your host folder:
docker run --rm -it -v "$PWD:/work" -w /work robot-demo
# The default CMD runs: dataset.sh && run_demo.sh

# After it finishes:
ls results/
