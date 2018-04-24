# Automatic Snapshots for Google (gcloud) Compute Engine

Bash script for Automatic Snapshots and Cleanup on Google Compute Engine based on label `auto-snapshot`.

Highly inspirated by [jacksegal/google-compute-snapshot](https://github.com/jacksegal/google-compute-snapshot).

## How it works
gcloud-snapshot.sh will:

- Get all the Disk IDs with label `auto-snapshot=true`
- Take a snapshot of each Disk
- The script will then delete all associated snapshots taken by the script for the Instance that are older than 7 days (optional: [default snapshot retention can be changed by using -d flag](#snapshot-retention))

## License

MIT License

Copyright (c) 2018 Loic Mahieu

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
