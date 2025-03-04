# API definition

## Overview

This repo convert API type definitions in `api.rkt` to rust and typescript
by the power of s-expr and racket language.

This repo is both a rust package and a npm package.

## Usage

```shell
# First install racket

# generate rust interface
racket rust.rkt < api.rkt > src/lib.rs
# generate typescript interface
racket typescript.rkt < api.rkt > index.ts
```
