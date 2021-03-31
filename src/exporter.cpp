#include <string>
#include <vector>
#include <cstdint>

#include <gif.h>

#include <Godot.hpp>
#include <Reference.hpp>
#include <Image.hpp>

using namespace godot;

class ExporterClass : public Reference
{
    GODOT_CLASS(ExporterClass, Reference);

public:
    ExporterClass() {}

    /** `_init` must exist as it is called by Godot. */
    void _init() {}


    void log(std::string text) {
      Godot::print(String(text.c_str()));
    }


    int write(String basename, Array frames, int color_type, int framerate)
    {

      std::string extension = ".gif";
      std::string fileName = basename.alloc_c_string() + extension;
      log(fileName);


      Variant firstFrame = frames[0];
      Image *firstImage = Object::cast_to<Image>(firstFrame.operator Object *());
      int width = firstImage->get_width();
      int height = firstImage->get_height();

      int delay = 100.0 / framerate;
      GifWriter g;
      GifBegin(&g, fileName.c_str(), width, height, delay);


      for (int i = 0; i < frames.size(); i++)
      {
        Variant frame = frames[i];
        Image *image = Object::cast_to<Image>(frame.operator Object *());

        image->convert(Image::FORMAT_RGBA8); // maybe we can use rbga32f directly


        const uint8_t *data = image->get_data().read().ptr();
        std::vector<uint8_t> gif_frame(&data[0], &data[image->get_data().size()]);
        

        GifWriteFrame(&g, gif_frame.data(), width, height, delay);

        Dictionary progress;
        progress["step"] = "Writing frames";
        progress["value"] = i;
        progress["max_value"] = frames.size();


        emit_signal("update_progress", progress);
      }

      GifEnd(&g);


      return 0;
    }


    static void _register_methods()
    {
      register_method("write", &ExporterClass::write);

      /**
       * The line below is equivalent to the following GDScript export:
       *     export var _name = "ExporterClass"
       **/
      // register_property<ExporterClass, String>("base/name", &ExporterClass::_name, String("ExporterClass"));

      /** Alternatively, with getter and setter methods: */
      // register_property<ExporterClass, int>("base/value", &ExporterClass::set_value, &ExporterClass::get_value, 0);

      /** Registering a signal: **/
      // register_signal<ExporterClass>("signal_name");
      register_signal<ExporterClass>("update_progress", "progress", GODOT_VARIANT_TYPE_DICTIONARY);
    }

    String _name;
    int _value;

    void set_value(int p_value)
    {
      _value = p_value;
    }

    int get_value() const
    {
      return _value;
    }
};


/** GDNative Initialize **/
extern "C" void GDN_EXPORT godot_gdnative_init(godot_gdnative_init_options *o)
{
  godot::Godot::gdnative_init(o);
}

/** GDNative Terminate **/
extern "C" void GDN_EXPORT godot_gdnative_terminate(godot_gdnative_terminate_options *o)
{
  godot::Godot::gdnative_terminate(o);
}

/** NativeScript Initialize **/
extern "C" void GDN_EXPORT godot_nativescript_init(void *handle)
{
  godot::Godot::nativescript_init(handle);

  godot::register_class<ExporterClass>();
}
