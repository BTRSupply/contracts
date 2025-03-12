#!/bin/bash
DEPLOYER=${DEPLOYER:-0x57b3771f6b772c52e81646aa007d1ab28d91b3fe} # default to deployer 1
./target/release/createxcrunch create3 --caller $DEPLOYER --leading 1