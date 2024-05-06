# PSRAM

## Features
<!-- * Programmable prescaler
    * max division factor is up to 2^20
    * can be changed ongoing
* 32-bit programmable timer counter and compare register
* Auto reload counter
* Multiple clock source
    * internal division clock
    * external low-speed clock
* Multiple counter mode
    * up counting
    * down counting
* Input capture mode support
    * 1 channel
    * rise or fall trigger
* Maskable overflow interrupt
* Static synchronous design
* Full synthesizable -->

FULL vision of datatsheet can be found in [datasheet.md](./doc/datasheet.md).

## Build and Test
```bash
make comp    # compile code with vcs
make run     # compile and run test with vcs
make wave    # open fsdb format waveform with verdi
```