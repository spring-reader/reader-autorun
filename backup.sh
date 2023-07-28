#!/bin/bash

tar -czf storage.tar.gz ./storage
git checkout backup
git add storage.tar.gz
git commit -s -m "backup:$(date)"
git push --set-upstream origin backup
