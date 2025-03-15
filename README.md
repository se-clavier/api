# API definition

## Overview

This repo convert API type definitions in `api.rkt` to rust and typescript
by the power of s-expr and racket language.

This repo is both a rust package and a npm package.

## Usage

```shell
make prepare # install racket
make .       # generate index.ts and src/lib.rs
```
