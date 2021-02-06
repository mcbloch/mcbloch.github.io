---
title: "Reverse engineering the Skagen Jorn"
created_at: 2021-02-06
kind: article
---

## Introduction

In March of 2019, I bought myself a hybrid smart watch. I wanted a "smarter"
watch that could do more than just tell the time, but still looked like a normal
watch. The one I landed on was the Skagen Jorn. After receiving it and seeing
what it did, I wondered how it worked. As it could not do _that_ much, the
protocol should be pretty straight-forward, right?

## Approach 1: Just look at it

The first thing I tried was using Androids built-in Bluetooth snooper and
observing what the official app sends to the watch and what it sent back using
Wireshark. The general structure of the communication became clear pretty
quickly:

- The phone can send "read requests" by sending a byte sequence starting with
  `01` and the other bytes indicating what to read. The device responds to those
  starting with `03`, the bytes indicating the thing that was requested and the
  data (e.g. if the device requests the battery level, it sends `01 08` and
  receives a response `03 01 32`, indicating the battery is at 50% charge)
- The phone can send "write requests" by sending a byte sequence starting with
  `02`, the bytes indicating what to write followed by the new data (e.g. if the
  phone wants to set the step goal to 10000, it sends `02 10 10 27 00 00`
  (notice how the goal is a little-endian integer))

The function of the buttons can be changed by sending a byte sequence starting
with `02 0b 32`, then the number of which button to use, and one of the byte
sequences. As most of the functions are just a combination of two identical
bytes. I tried all the different combinations to see what they did, which gave
me either no result at all or one of the functions the app allowed as well,
except for one. When I tried function `0d0d` and pressed the button, the watch
turned into a stopwatch, which was not possible using the official app. This
sparked my interest into finding and documenting all features of the watch and
its documentation.

So, I continued with trial-and-error until I had discovered how to get and write
most of the important values. I even started implementing it for
[GadgetBridge][gadgetbridge] (an open-source smart watch Android app) and got
almost feature-par with the official app, only missing detailed sleep and step
count data. I began looking into the large blobs of data that were sent and try
to make sense of it, but I didn't get far with that so I started looking into
reverse engineering the official app. After seeing that the Java code was
partially obfuscated, contained code for Misfit/Fossil watches and did a lot of
its parsing in a separate C++ library (which was even harder to
decompile/understand), I lost motivation to continue and when my watch straps
broke and I stopped using the app recently, the project became shelved...

## Approach 2: Reverse engineering

Recently (February 2021), I had some spare time on my hands and decided to pick
this project up again. I booted up Ghidra, retrieved the C++ library from the
updated official app and started analyzing it, renaming variables, filling in
struct definitions, trying not to get too mad at the way some functions were
implemented, ... One of the best entry points is its JNI (Java Native Interface)
functions, look at how the classes were converted from Java (which I knew the
structure of from the decompiled apk) and see how this translated to C++. Trying
to work backwards from there did not always work, so sometimes I had to make
some estimated guesses on how some functions worked. My two major goals were
getting the sleep/steps data (which was mostly done in the C++ code) and the
communication between the device and the phone (which was done in the Java
code).

### Communication between phone and the watch

I was able to document (as far as I know) all the commands the official
app _could_ send, which includes non-Skagen commands. In fact, the code that
does the communication with the Skagen watch is Misfit-code and displayed using
Fossil-code (is it confusing enough yet?). I quickly figured out that all the
commands were obfuscated, so I started sifting through all 182 obfuscated
Java-files in `com.misfit.ble.obfuscated` to see if it was a command or not, if
it was, write its name, request format and (if applicable) response format. The
name was simply the result of the `getRequestName` method. The request format I
got by looking at the ByteBuffer constructed in the (obfuscated) `aZ` method and
find the meaning behind the bytes by looking at the `getRequestDescriptionJSON`
method. The response format I found by looking at the `handleResponse` function
(note: you'll see that a lot of the responses contain question marks, that is
because this function does not use them, thus I cannot be sure what they should
be) and their meaning again thanks to the app's JSON interface with the
`getResponseDescriptionJSON` method. After about many hours I had documented
everything and can be found [here][commands]. There are a lot of commands, so I
won't go into too much detail on them here, but here is a tl;dr:

- As expected, every command is identified by its byte-prefix and contains
  (little-endian) arguments
- Commands are either request/response (01/03), write (02) or file-interactions
  (more complex)
- There is _a lot_ of functions/features the official app does not check or use,
  and I'm going to be testing which actually work, regardless of whether or not
  the app allows them
- The protocol is not bad (which is surprising if you look at the implementing
  code, not just because it was decompiled, but I can probably write a blog post
  about that on its own)
- The activity file format (or at least its parsing) has changed slightly
  between the old and new app

### The files

The watch has a pretty extensive file interface with reading, writing, deleting,
listing all files, ... But for my purpose, only one file was important, that
being the file at handle `0x0101`, containing the "activity data". This file
consists of a header (described below) and a set of 2-byte entries that contain
both the step count and "variance" (I assume that is movement), from which the
phone calculates the total steps taken, calories burned, etc.

The header consists of the following parts:

- 2 bytes: file handle
- 2 bytes: file format (the old app supports 6 formats (0x0011, 0x0012, 0x0013,
  0x0014, 0x0f01 and 0x0f02), the new app supports 3 (0x0014, 0x0016 and
  0x0080), luckily the Skagen Jorn uses 0x0014 :) )
- 4 bytes: file length
- 4 bytes: timestamp when the file was created, in UTC seconds
- 2 bytes: milliseconds of the timestamp
- 2 bytes: timezone in minutes after UTC
- 2 bytes: absolute number (not sure what this means, but it appears unused)
- 1 byte: minor\_version
- 1 byte: number of special fields (N)
- N\*2 bytes: 1 byte key, 1 byte value for "special fields" (also not sure what
  these mean)

After that, each two-byte pair contains the data of one minute, starting at the
timestamp from the header. If the first byte is smaller than 200 (0xc8), it
parses it like a normal activity entry, otherwise the first byte indicates how
the data following it should be interpreted. I have not spent a lot of time on
the latter, as the data from my watch only consists of normal entries, but you
can find the names of the functions (which give a clue as to what the data does)
in my [file notes][files].

The regular activity entries come in 2 types, indicated by bit 0 of the first
byte. If that bit is 0, the first byte indicates the number of steps and the
second byte the square root of the variance, divided by 64 (so `var = second_byte 
* second_byte * 64`), otherwise the number of steps is bits 4 through 1 of
the first byte and the variance the combination (concatenation) of the highest 4
bits of the first byte and the highest 6 bits of the second byte. The remaining
2 bits are unused in the new implementation, but were used by the old
implementation to calculate an unknown variable by multiplying these bits with
25 and adding one, or using a hard-coded 10000 for the other type of entry.

The steps can be read from this directly, and the sleep data is constructed by
looking at the number of consecutive minutes that have a variance lower than a
certain value. With this, I have enough information to start experimenting with
what the watch is _really_ able to do and make a GadgetBridge implementation
that has more features than the original app. _mission accomplished_

[gadgetbridge]: https://codeberg.org/Freeyourgadget/Gadgetbridge
[commands]: https://robbevanherck.be/skagen_commands.md
[files]: https://robbevanherck.be/skagen_files.md
