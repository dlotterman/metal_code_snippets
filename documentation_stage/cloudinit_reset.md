# Reset cloud-iniut without reboot

Taken from [StackOverflow](https://stackoverflow.com/questions/23065673/how-to-re-run-cloud-init-without-reboot)

```
cloud-init clean --logs
cloud-init init --local
cloud-init init
cloud-init modules --mode=config
cloud-init modules --mode=final
```
