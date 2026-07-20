# .NET code-page source metadata

The source set is pinned to the official `dotnet/runtime` repository revision `dbb2178288bb4e1e8f1fde3958be3bd75573c459`, ordered aggregate SHA-256 `710a341a09f90bec6ec66e01d44620bf6485b4420b92a6075e45f5e38f860cdf`. It defines the `x-Europa`/29001 data and independently confirms that .NET's `x-cp50227` profile delegates to CP936 (the exact CP936 mapping is separately pinned from Unicode).

All retained .NET files are MIT-licensed under the exact upstream `LICENSE.TXT`, SHA-256 `cfc21f5e8bd655ae997eec916138b707b1d290b83272c02a95c9f821b8c87310`. They are repository-only generator/oracle evidence and are excluded from Hex; the generated tables and independently written Elixir codecs remain LGPL-2.1-or-later.

| Artifact | Official upstream | SHA-256 | License |
|---|---|---|---|
| `LICENSE.TXT` | <https://github.com/dotnet/runtime/blob/dbb2178288bb4e1e8f1fde3958be3bd75573c459/LICENSE.TXT> | `cfc21f5e8bd655ae997eec916138b707b1d290b83272c02a95c9f821b8c87310` | MIT |
| `codepages.nlp` | <https://github.com/dotnet/runtime/blob/dbb2178288bb4e1e8f1fde3958be3bd75573c459/src/libraries/System.Text.Encoding.CodePages/src/Data/codepages.nlp> | `0cad998c5e9776cdbbfc34e5687931d771018f8df9c3bf741b3e2e676533e9fb` | MIT |
| `CodePageNameMappings.csv` | <https://github.com/dotnet/runtime/blob/dbb2178288bb4e1e8f1fde3958be3bd75573c459/src/libraries/System.Text.Encoding.CodePages/src/Data/CodePageNameMappings.csv> | `1b38a7fd3274cea7b30b9387b262901be664c951dc27389804ddce9a2ec07b9d` | MIT |
| `PreferredCodePageNames.csv` | <https://github.com/dotnet/runtime/blob/dbb2178288bb4e1e8f1fde3958be3bd75573c459/src/libraries/System.Text.Encoding.CodePages/src/Data/PreferredCodePageNames.csv> | `b9fb8070e52a3f5c2988e3fcc550d1a06e163618a8abc27e9fc5bb3b101b7e7b` | MIT |
| `BaseCodePageEncoding.cs` | <https://github.com/dotnet/runtime/blob/dbb2178288bb4e1e8f1fde3958be3bd75573c459/src/libraries/System.Text.Encoding.CodePages/src/System/Text/BaseCodePageEncoding.cs> | `ba919a94e5b6fd6c2dc0677f93126b814dd166b7ccae794d91b90ef3be2d9e21` | MIT |
| `SBCSCodePageEncoding.cs` | <https://github.com/dotnet/runtime/blob/dbb2178288bb4e1e8f1fde3958be3bd75573c459/src/libraries/System.Text.Encoding.CodePages/src/System/Text/SBCSCodePageEncoding.cs> | `83c59ede4ed945879c7f28d42f312b4ceee844e8dcd522fd208c80d20e896b26` | MIT |
| `EncodingCodePages.cs` | <https://github.com/dotnet/runtime/blob/dbb2178288bb4e1e8f1fde3958be3bd75573c459/src/libraries/System.Text.Encoding.CodePages/tests/EncodingCodePages.cs> | `5817fc9137fe389ff1a4d12602a86f31eae9913f7f828fea1c4bbbe89cfa9984` | MIT |
| `CodePagesEncodingProvider.cs` | <https://github.com/dotnet/runtime/blob/dbb2178288bb4e1e8f1fde3958be3bd75573c459/src/libraries/System.Text.Encoding.CodePages/src/System/Text/CodePagesEncodingProvider.cs> | `627511f91bb03d793b4e60f25f52480527a59f8facadd23231da7384a2c74e34` | MIT |
