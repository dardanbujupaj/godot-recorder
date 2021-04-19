# godot-recorder
Addon to record a viewport in Godot and automatically convert the recording into an animation.

## Usage
Download the plugin from the Godot Asset Library and enable it in the project settings. 

Add the **Recorder**-Node to your main scene (or any other scene, doesn't really matter). 

The **R**-Key is used to start/stop the recording by default. This can be changed in the Trigger-properties.


## Configuration

### Framerate
The framerate of the recording.
Make sure to pick a value thats actually possible to record. (If you're using a framerate higher than the one your game is running at, you will get strange results. Also GIF allows maximal Framerate of 50)
Higher framerate will give you smoother animations but will also make the filesize larger.


### Animation format
Currently there are two available formats to export an animation to:

#### GIF
Produces a GIF of the recording. 
Support on basically every platforms and probably the format you want to go for.

#### APNG (Animated PNG)
The resulting file is an [animated PNG](https://developer.mozilla.org/en-US/docs/Mozilla/Tech/APNG).
Animated PNGs are supported by all modern browsers.

#### PNG sequence
Animation is stored as a series of PNG-images.
The filenames are extended with the index of the animation (e.g \_0001.png, \_0002.png, ...).


### Color type
You can choose between four color types.

| Color type | Color | Transparent | Byte/Pixel |
|-|:-:|:-:|:-:|
| Greyscale | | | 1 |
| Greyscale Alpha | | x | 2 |
| Truecolor | x | | 3 |
| Truecolor Alpha | x | x | 4 |

On way to make use of of the transparent types (Alpha), is to make the background of the viewport transparent. (`get_viewport().transparent_bg = true` in GDScript)

Note that this won't work for GIFs as the library used only supports RBGA Input but ignores the transparency value (A). You may still choose to use Greyscale color type, which will record the frames in greyscale.


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
# generate c++ bindings 
cd godot-cpp
scons platform=linux target=release generate_bindings=yes -j4

# build binaries
scons platform=linux target=release -j4
```


## Roadmap
I'm still trying to get ffmpeg to work with the Godot cpp bindings.
This would allow for a lot more 
