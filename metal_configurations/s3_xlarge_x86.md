### Notes on the s3.xlarge.x86

#### LSI 3008-IT
While the LSI / Avago / Broadcom 3008 is normally listed as being capable of certain features including remedial RAID, the controllers installed in the `s3` are in the "IT" vs "IR" mode, which is essentially passthrough mode, restricting the cards ability to do anything featureful. 

If you go so far as to install storcli, the operator will be return "Un-supported feature / command" in response to VD and other creation commands
