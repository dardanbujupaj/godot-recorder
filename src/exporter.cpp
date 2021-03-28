#include <Godot.hpp>
#include <Reference.hpp>

using namespace godot;

class ExporterClass : public Reference {
    GODOT_CLASS(ExporterClass, Reference);
public:
    ExporterClass() { }

    /** `_init` must exist as it is called by Godot. */
    void _init() { }

    void test_void_method() {
        Godot::print("This is test");
    }

    Variant method(Variant arg) {
        Variant ret;
        ret = arg;

        return ret;
    }

    static void _register_methods() {
        register_method("method", &ExporterClass::method);

        /**
         * The line below is equivalent to the following GDScript export:
         *     export var _name = "ExporterClass"
         **/
        register_property<ExporterClass, String>("base/name", &ExporterClass::_name, String("ExporterClass"));

        /** Alternatively, with getter and setter methods: */
        register_property<ExporterClass, int>("base/value", &ExporterClass::set_value, &ExporterClass::get_value, 0);

        /** Registering a signal: **/
        // register_signal<ExporterClass>("signal_name");
        // register_signal<ExporterClass>("signal_name", "string_argument", GODOT_VARIANT_TYPE_STRING)
    }

    String _name;
    int _value;

    void set_value(int p_value) {
        _value = p_value;
    }

    int get_value() const {
        return _value;
    }
};

/** GDNative Initialize **/
extern "C" void GDN_EXPORT godot_gdnative_init(godot_gdnative_init_options *o) {
    godot::Godot::gdnative_init(o);
}

/** GDNative Terminate **/
extern "C" void GDN_EXPORT godot_gdnative_terminate(godot_gdnative_terminate_options *o) {
    godot::Godot::gdnative_terminate(o);
}

/** NativeScript Initialize **/
extern "C" void GDN_EXPORT godot_nativescript_init(void *handle) {
    godot::Godot::nativescript_init(handle);

    godot::register_class<ExporterClass>();
}