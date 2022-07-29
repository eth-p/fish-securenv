# securenv

The main `securenv` command.



## Subcommands

[**securenv apply**](securenv-apply.md)  
Apply an environment variable to the current shell instance.

[**securenv erase**](securenv-erase.md)  
Permanently erase a securely-stored variable entry.

[**securenv list**](securenv-list.md)  
List the names of all the securely-stored variable entries.

[**securenv list-applied**](securenv-list-applied.md)  
List the names of all the `securenv apply`-ed variable entries.

[**securenv read**](securenv-read.md)  
Print out the value of a securely-stored variable entry.

[**securenv set**](securenv-set.md)  
Create or update a securely-stored variable entry.

[**securenv unapply**](securenv-unapply.md)  
Un-apply an environment variable from the current shell instance.

[**securenv wrap**](securenv-wrap.md)  
Wrap a `fish` function or shell command to read and use a securely-stored variable when executed.




## Usage

Securenv is a set of functions that stores and retrieves potentially-sensitive environment variables. Rather than keeping something like your `GITHUB_TOKEN` accessible to every last command you run, potentially exposing it to exfiltration by unrelated scripts or commands, `securenv` lets you only load it when you need it.

There are two ways you can use `securenv`: loading environment variables on demand with [securenv apply](securenv-apply.md), or wrapping commands  with [securenv wrap](securenv-wrap.md) to load and export the environment variables when called.

> **Note:**
> When reading or applying variables, or running wrapped commands, you may be prompted by a pinentry program for `gpg`. This is required to decrypt the variable, and it acts to confirm your intent to use it.



### Creating a secure environment variable entry

To create a secure environment variable entry, you can use [securenv set](securenv-set.md). This will prompt you for the variable value.

```fish
securenv set VARIABLE_NAME
```



### Modifying a secure environment variable entry

If you want to change the value of an entry, you can use the same [securenv set](securenv-set.md) command to change its value. 




### Erasing a secure environment variable entry

If you want to erase an entry from the storage, you can use the [securenv erase](securenv-erase.md) command for that:

```fish
securenv erase VARIABLE_NAME
```

 You will be prompted for confirmation.




### Applying a secure environment variable

To export a secure environment variable in the current shell instance, you can use the [securenv apply](securenv-apply.md) command.

```fish
securenv apply VARIABLE_NAME
```

If you want to apply it under a different name than `VARIABLE_NAME`, you can use the `--as` flag:

```fish
securenv apply VARIABLE_NAME --as=GITHUB_TOKEN
```

To see a list of applied variables, you can use the [securenv list-applied](securenv-list-applied.md) command.



### Un-applying a secure environment variable

When you're done with the environment variable, you can un-apply it from the current shell instance using the [securenv unapply](securenv-unapply.md) command.

```fish
securenv unapply VARIABLE_NAME
```

This will un-apply *all* instances of `VARIABLE_NAME`. For example, if you have it applied as both `foo` and `var`, both those variables will be unset.




### Applying a secure environment variable to a specific command

Sometimes, you might not want to globally export a secure environment variable to all commands. The [securenv wrap](securenv-wrap.md) command can help with that, by wrapping a single command to load and export the secure environment variable at execution time.

```fish
securenv wrap COMMAND VARIABLE_NAME
```

If you want to apply it under a different name than `VARIABLE_NAME`, you can use the `--as` flag:

```fish
securenv wrap COMMAND VARIABLE_NAME --as=GITHUB_TOKEN
```



## Setup

If you don't already have `gpg` installed and set up with an encryption key, you can use your favourite package manager to install GPG and `gpg --full-generate-key` to create a key for it.

We recommend using `RSA and RSA`, `4096` bits, and no expiry. When creating the key, make sure to note down the email address you use for your identity (e.g. `firstname@localhost`).

Once you have a key generated, configure `securenv` to use it by setting the `$securenv_gpg_user` variable:

```fish
set -e securenv_gpg_user
set -U securenv_gpg_user "firstname@localhost"
```



## Configuration

`$securenv_provider` (string)  
Change the storage provider backend for `securenv`.  
Natively, this only supports `gpg` as a storage provider.

`$securenv_gpg_user` (string)  
The email address of the `gpg` identity to encrypt the variables with. As data is meant to be both encrypted and decrypted locally, please make sure you use an identity that has both a public and private key.

`$securenv_gpg_store` (string)  
The directory where encrypted variables will be stored. By default, this will be `~/.local/share/securenv/data`.



