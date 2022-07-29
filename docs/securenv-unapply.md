# securenv unapply

Un-apply an environment variable from the current shell instance.

This will un-apply *all* instances of the variable. For example, if you have it applied as both `foo` and `var`, both those variables will be unset.

## Usage

| Command                       | Description                                               |
| ----------------------------- | --------------------------------------------------------- |
| `securenv unapply <VARIABLE>` | Unapply all exported variables sourced from `<VARIABLE>`. |
| `securenv unapply --all`      | Unapply all exported secure variables.                    |

