# vim-mrw

This plugin provides to switch a file to edit **M**ost **R**ecently **W**ritten files by popup window.  

## Usage

### :MRW [-sortby={sortby-value}] [-reverse]
Show most recently written files by popup window. Then you can edit a selected file.   
{sortby-value} is a value of following:  

#### 'time' (default)
Sort by last modification time of the file.

#### 'filename'
Sort by file name of the path.

#### 'directory'
Sort by directory of the path.

![](https://raw.githubusercontent.com/rbtnn/vim-mrw/master/mrw.gif)

## Requirements

* Vim must be compiled with `+popupwin` feature

## Concepts

* This plugin does not provide to customize user-settings.
* This plugin provides only one command.

## License

Distributed under MIT License. See LICENSE.
