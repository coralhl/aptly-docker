#!/bin/bash
tag_base="latest"

# Сборка
docker buildx build --output type=docker --progress=plain -f Dockerfile -t coralhl/aptly:$tag_base .
# Заливка в регистр
docker push coralhl/aptly:$tag_base
