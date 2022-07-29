# securenv wrap

Wrap a `fish` function or shell command to read and use a securely-stored variable when executed.

This will rewrite the function to locally apply (i.e. only for that function/command and whatever it executes) the variable as an exported environment variable.



## Usage

| Command                              | Description                                                  |
| ------------------------------------ | ------------------------------------------------------------ |
| `securenv wrap <COMMAND> <VARIABLE>` | Wrap the `<COMMAND>` command to use the secure variable `<VARIABLE>` whenver executed. |



## Flags

| Flag          | Description                              |
| ------------- | ---------------------------------------- |
| `--as=<NAME>` | Export the variable as a different name. |

