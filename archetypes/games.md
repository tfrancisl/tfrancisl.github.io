---
date: '{{ .Date }}'
draft: true
title: '{{ replace .File.ContentBaseName "-" " " | title }}'
params:
  genre: []
  developer: ''
  publisher: ''
---
