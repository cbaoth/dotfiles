#!/bin/env bash

sudo hddtemp "$@" 2>/dev/null || echo -1

