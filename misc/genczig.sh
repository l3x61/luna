#!/bin/sh

zig translate-c c.h -lc > c.zig
