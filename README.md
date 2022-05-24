# Vanity name registry

This project demonstrate usage for registration vanity names with "Commitment scheme" technique to prevent front-running.
Also what checked technics with fixed gas limit and "submarine send", but I have desided that commitment easy and more cheaper to use and make contracts more flexible. In order to track vanity names, erc721 used for marking. So it could be easy send to different receiptients for changing ownership or sell.

Intallation:

```shell
yarn
cp .env.example .env
```

Env explanation
```
COMMIT_TIME - time for initial commitment with secret to prevent front running (in seconds)
DURATION_TIME - time for name reservation (in seconds)
ETH_PER_LEN - price per one char symbol (in eth)
MIN_NAME_LENGTH - min length name to be applied through controller (number)

```

Run tests:

```shell
hh test
```
