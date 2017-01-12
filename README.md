# exifsort

The following script was written in bash on Ubuntu Linux and automatically sorts your images into directories based on the date and time the photo was taken. How does it do this? By making use of the EXIF data your digital camera stores inside the image. The date and time the photo was taken is stored in that EXIF data. When an image doesn't have EXIF data (such as when it was downloaded from the Internet, or taken from a camera that doesn't support adding EXIF data), it will use the files last-modified time if it matches the time extracted from the file's filename..

CHANGELOG:
- Added exiftool as preffered EXIF extractor.
- The script will add to the name of processed files timestamp and CRC or MD5 hash - to minimise the risk of overwriting a file with a different one sharing the same EXIF time.
- Optionally - If EXIF is not present it will use the files last-modified time if it matches the time extracted from the file's filename.
- Optionally - If JPEG_TO_JPG is set to TRUE, long file extensions (jpeg, mpeg, tiff) will be replaced with short file extension (jpg, mpg, tif).
- Supported files: jpg, jpeg, png, tif, tiff, gif, xcf, avi, mp4, mpg, mpeg, mov, 3gp, raf, cr2
- If USE_TREE_FOLDER is set to TRUE, an image created 2017-01-13 will be placed in folder /2017/01/13. When set to FALSE the destination folder would be 2017-01-13.
- Added logging (./exifsort.log).
- Images with no EXIF information provided can be left without any change (NO_EXIF_ACTION set to "NONE")

First, this should be run in the top-most directory of wherever your pictures are stored. If you have pictures/foldername/somepics/ and pictures/anotherfolder/morepics, run it from your pictures/ directory.

There are quite a few opportunities to improve this script -- and some cautionary notes as well -- marked within the script with FIXME tags. I'm already finished sorting my images, but anyone is welcome to contribute suggestions and improvements, which I'll look into incorporating the next time I'm using this.

Usage: Copy the script into a file, editing options where appropriate, and save it. Make it executable and run it from the command line or window, from the directory where your pictures are stored. No command-line arguments. Back up your stuff first :)
