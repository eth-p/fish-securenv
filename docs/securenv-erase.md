# securenv erase

Permanently erase a securely-stored variable entry.

By default, erased variables will also be un-applied from all `fish` shell instances.



## Usage

| Command                     | Description                      |
| --------------------------- | -------------------------------- |
| `securenv erase <VARIABLE>` | Erase the variable `<VARIABLE>`. |



## Flags

| Flag               | Description                       |
| ------------------ | --------------------------------- |
| `--force`          | Do not prompt to erase the entry. |
| `--keep-in-memory` | Do not un-apply the variable.     |

