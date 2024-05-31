# PSRAM

## Features
* Support SerialRAM(SPI, QPI and OPI mode)
* Programmable prescaler
    * max division factor is up to 2^20
    * can be changed ongoing
* Maskable overflow interrupt
* Static synchronous design
* Full synthesizable

FULL vision of datatsheet can be found in [datasheet.md](./doc/datasheet.md).

## Build and Test
```bash
make comp    # compile code with vcs
make run     # compile and run test with vcs
make wave    # open fsdb format waveform with verdi
```