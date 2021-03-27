# godot-recorder

Addon to record a viewport in Godot and automatically convert the recording into an animation.

## Usage
Download the plugin from the Godot Asset Library and enable it in the project settings. 

Add the **Recorder**-Node to your main scene (or any other scene, doesn't really matter). 

The **R**-Key is used to start/stop the recording by default. This can be changed in the Trigger-properties.


## Configuration
### Framerate
The framerate of the recording.
Make sure to pick a value thats actually possible to record. (0 < framrate <= 60 should be reasonable)
Higher framerate will give you smoother animations but will also make the filesize larger.


### Color type
You can choose between four color types.


| Color type | Color | Transparent | Byte/Pixel |
|-|:-:|:-:|:-:|
| Greyscale | | | 1 |
| Greyscale Alpha | | x | 2 |
| Truecolor | x | | 3 |
| Truecolor Alpha | x | x | 4 |

On way to make use of of the transparent types (Alpha), is to make the background of the viewport transparent. (`get_viewport().transparent_bg = true` in GDScript)

### Animation format
Currently there are two available formats to export an animation to:

#### APNG (Animated PNG)
The resulting file is an [animated PNG](https://developer.mozilla.org/en-US/docs/Mozilla/Tech/APNG).
Animated PNGs are supported by all modern browsers.

#### PNG sequence
Animation is stored as a series of PNG-images.
The filenames are extended with the index of the animation (e.g \_0001.png, \_0002.png, ...).

### Trigger
This option sets the event which starts/stops the recording.
It can be set to any InputEvent.
A common use case is, to set it to an `InputEventAction` with the action `record` which can be configured in `Project Settings > Input Map`.

### Export path
The folder in which the recordings should be saved. 
This is set to [user://](https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html#user-path-persistent-data) by default, but any valid filepath can be choosen.



# Development
## Build binaries

Use the following code to build linux binaries
```
scons platform=linux
```



## TODO
- Implement exporter (ffmpeg wrapper)
  - https://github.com/leandromoreira/ffmpeg-libav-tutorial
- Github workflow to release versions
  1. create binaries for every platform and upload as artifacts
    - https://github.com/actions/upload-artifact
  2. Download all artifacts and commit to repository
    - https://github.com/actions/download-artifact
  3. create tag
