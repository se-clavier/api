# API definition

## Overview

This repo convert API type definitions in `src/lib.rs` to Json Schema, then to typescript,
to maintain consistency between the frontend and backend.

This repo is both a rust package (for generate Json Schema) and a npm package 
(to convert Json Schema to typescript at `index.d.ts`, and to be referenced in frontend).

## Usage

```
npm i
npm run build
```