#!/bin/bash

set -Eeuo pipefail

pandoc \
  --from=markdown \
  --to=gfm \
  --citeproc \
  --bibliography=./citations.bib \
  --output README.md \
  anonymization-source.md &&
  npm_config_yes=true \
    npx doctoc \
    --github \
    README.md
