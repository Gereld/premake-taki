# premake-taki

This is the premake-taki project.
Taki is a module for Premake 5 to add support for multiple generators. Currently only the Ninja generator is implemented. C++ is the only language supported.

## Installing

In your Premake 5 modules folder:

```sh
git clone https://github.com/Gereld/premake-taki taki 
```

Add this line in your premake5-system.lua:

```sh
require 'taki'
```
See Premake's documentation on how to use [modules](https://premake.github.io/docs/Using-Modules).

Example:

```sh
mkdir my-modules
cd my-modules
git clone https://github.com/Gereld/premake-taki taki 
echo "require 'taki'" > premake5-system.lua

set PREMAKE_PATH=path-to/my-modules
```

## Usage

```sh
premake5 ninja
```

## References
- https://github.com/premake/premake-core
- https://github.com/jimon/premake-ninja

## Goals
- Implement a generator for remake
- Add support for C++20 modules dynamic dependency.