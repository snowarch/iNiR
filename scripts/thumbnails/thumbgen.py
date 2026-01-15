#!/usr/bin/env python3

# From https://github.com/difference-engine/thumbnail-generator-ubuntu (MIT License)
# Since the script is small and the maintainers seem inactive to accept my PR (#11) I decided to just copy it over.
# When it gets merged and the python package gets updated we can just use it

import os
import sys
import hashlib
import subprocess
import urllib.parse
from multiprocessing import Pool
from pathlib import Path
from typing import List, Union

import click
from loguru import logger
from tqdm import tqdm

# Try to import GnomeDesktop, but don't fail if not available
GNOME_DESKTOP_AVAILABLE = False
try:
    import gi
    gi.require_version("GnomeDesktop", "4.0")
    from gi.repository import Gio, GnomeDesktop
    GNOME_DESKTOP_AVAILABLE = True
    thumbnail_size_map = {
        "normal": GnomeDesktop.DesktopThumbnailSize.NORMAL,
        "large": GnomeDesktop.DesktopThumbnailSize.LARGE,
        "x-large": GnomeDesktop.DesktopThumbnailSize.XLARGE,
        "xx-large": GnomeDesktop.DesktopThumbnailSize.XXLARGE,
    }
except (ImportError, ValueError):
    pass

# Pixel sizes for thumbnail directories (freedesktop spec)
thumbnail_pixel_sizes = {
    "normal": 128,
    "large": 256,
    "x-large": 512,
    "xx-large": 1024,
}

factory = None
current_size = "large"
logger.remove()
logger.add(sys.stdout, level="INFO")
logger.add("/tmp/thumbgen.log", level="DEBUG", rotation="100 MB")


def get_thumbnail_path(fpath: str, size_name: str) -> str:
    """Calculate thumbnail path using the same method as QML ThumbnailImage."""
    # Encode each path component (like QML's encodeURIComponent)
    parts = fpath.split("/")
    encoded = "/".join(urllib.parse.quote(p, safe="") for p in parts)
    url = f"file://{encoded}"
    md5 = hashlib.md5(url.encode()).hexdigest()
    cache_dir = os.path.expanduser(f"~/.cache/thumbnails/{size_name}")
    return f"{cache_dir}/{md5}.png"


def make_thumbnail_imagemagick(fpath: str, size_name: str) -> bool:
    """Generate thumbnail using ImageMagick (fallback method)."""
    thumb_path = get_thumbnail_path(fpath, size_name)

    if os.path.exists(thumb_path):
        logger.debug("FRESH       {}".format(fpath))
        return False

    # Ensure directory exists
    os.makedirs(os.path.dirname(thumb_path), exist_ok=True)

    size = thumbnail_pixel_sizes[size_name]
    # Use [0] suffix to get first frame (works for images and animated gifs)
    cmd = ["magick", f"{fpath}[0]", "-resize", f"{size}x{size}", thumb_path]

    try:
        result = subprocess.run(cmd, capture_output=True, timeout=30)
        if result.returncode == 0:
            logger.debug("OK_MAGICK   {}".format(fpath))
            return True
        else:
            logger.debug("ERROR_MAGICK {}".format(fpath))
            return False
    except (subprocess.TimeoutExpired, FileNotFoundError) as e:
        logger.debug("ERROR_MAGICK {} - {}".format(fpath, str(e)))
        return False


def make_thumbnail(fpath: str) -> bool:
    global current_size

    # Try GnomeDesktop first if available
    if GNOME_DESKTOP_AVAILABLE and factory is not None:
        mtime = os.path.getmtime(fpath)
        f = Gio.file_new_for_path(str(fpath))
        uri = f.get_uri()
        info = f.query_info("standard::content-type", Gio.FileQueryInfoFlags.NONE, None)
        mime_type = info.get_content_type()

        if factory.lookup(uri, mtime) is not None:
            logger.debug("FRESH       {}".format(uri))
            return False

        if factory.can_thumbnail(uri, mime_type, mtime):
            thumbnail = factory.generate_thumbnail(uri, mime_type)
            if thumbnail is not None:
                logger.debug("OK          {}".format(uri))
                factory.save_thumbnail(thumbnail, uri, mtime)
                return True

        # GnomeDesktop failed, fall through to ImageMagick
        logger.debug("FALLBACK    {} (GnomeDesktop unsupported)".format(uri))

    # Fallback to ImageMagick
    return make_thumbnail_imagemagick(fpath, current_size)


@logger.catch()
def thumbnail_folder(*, dir_path: Path, workers: int, only_images: bool, recursive: bool, machine_progress: bool = False) -> None:
    all_files = get_all_files(dir_path=dir_path, recursive=recursive)
    if only_images:
        all_files = get_all_images(all_files=all_files)
    all_files = [str(fpath) for fpath in all_files]
    if machine_progress:
        completed = 0
        total = len(all_files)
        with Pool(processes=workers) as p:
            for result in p.imap(make_thumbnail, all_files):
                completed += 1
                print(f"PROGRESS {completed}/{total} FILE {all_files[completed-1]}")
                sys.stdout.flush()
    else:
        with Pool(processes=workers) as p:
            list(tqdm(p.imap(make_thumbnail, all_files), total=len(all_files)))


def get_all_images(*, all_files: List[Path]) -> List[Path]:
    img_suffixes = [".jpg", ".jpeg", ".png", ".gif"]
    all_images = [fpath for fpath in all_files if fpath.suffix in img_suffixes]
    print("Found {} images".format(len(all_images)))
    return all_images


def get_all_files(*, dir_path: Path, recursive: bool) -> List[Path]:
    if not (dir_path.exists() and dir_path.is_dir()):
        raise ValueError("{} doesn't exist or isn't a valid directory!".format(dir_path.resolve()))
    if recursive:
        all_files = dir_path.rglob("*")
    else:
        all_files = dir_path.glob("*")
    all_files = [fpath for fpath in all_files if fpath.is_file()]
    print("Found {} files in the directory: {}".format(len(all_files), dir_path.resolve()))
    return all_files

@click.command()
@click.option(
    "-d", "--img_dirs", required=True, help='directories to generate thumbnails seperated by space, eg: "dir1/dir2 dir3"'
)
@click.option(
    "-s", "--size", default="normal", type=click.Choice(["normal", "large", "x-large", "xx-large"]), help="Thumbnail size: normal, large, x-large, xx-large"
)
@click.option("-w", "--workers", default=1, help="no of cpus to use for processing")
@click.option(
    "-i", "--only_images", is_flag=True, default=False, help="Whether to only look for images to be thumbnailed"
)
@click.option("-r", "--recursive", is_flag=True, default=False, help="Whether to recursively look for files")
@click.option("--machine_progress", is_flag=True, default=False, help="Print machine-readable progress lines instead of a progress bar")
def main(img_dirs: str, size: str, workers: str, only_images: bool, recursive: bool, machine_progress: bool) -> None:
    img_dirs = [Path(img_dir) for img_dir in img_dirs.split()]
    global factory, current_size
    current_size = size

    if GNOME_DESKTOP_AVAILABLE:
        factory = GnomeDesktop.DesktopThumbnailFactory.new(thumbnail_size_map[size])
    else:
        logger.info("GnomeDesktop not available, using ImageMagick fallback")
        factory = None

    for img_dir in img_dirs:
        thumbnail_folder(dir_path=img_dir, workers=workers, only_images=only_images, recursive=recursive, machine_progress=machine_progress)
    print("Thumbnail Generation Completed!")


if __name__ == "__main__":
    main()
