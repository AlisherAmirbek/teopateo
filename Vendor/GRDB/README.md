# Vendored GRDB

This local Swift package vendors the GRDB sources used by TeoPateo.

Upstream:

- Repository: https://github.com/groue/GRDB.swift
- Version: 7.10.0
- Revision: 36e30a6f1ef10e4194f6af0cff90888526f0c115

Only the files needed by the `GRDB` product are included:

- `GRDB/`
- `Sources/GRDBSQLite/`
- `LICENSE`

The remote Swift Package dependency was replaced because Xcode also tries to
clone GRDB's optional `SQLiteCustom/src` submodule during package resolution,
even though TeoPateo uses system SQLite. That submodule checkout made clean
builds fail before the app code was compiled.
