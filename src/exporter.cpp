#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/timestamp.h>

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

    void test_void_method()
    {
        Godot::print("This is test");
    }

    String method()
    {
        return "hello godot";
    }

    int export_frames(Array frames, String filename)
    {
        Godot::print(filename);
        AVFormatContext *av_format_context;

        char *output_filename = filename.alloc_c_string();

        avformat_alloc_output_context2(&av_format_context, NULL, NULL, output_filename);
        if (!av_format_context)
        {
            printf("could not allocate memory for output format");
            return -1;
        }

        if (av_format_context->oformat->flags & AVFMT_GLOBALHEADER)
            av_format_context->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;

        if (!(av_format_context->oformat->flags & AVFMT_NOFILE))
        {
            if (avio_open(&av_format_context->pb, output_filename, AVIO_FLAG_WRITE) < 0)
            {
                printf("could not open the output file");
                return -1;
            }
        }

        AVDictionary *muxer_opts = NULL;

        /*
        if (sp.muxer_opt_key && sp.muxer_opt_value)
        {
            av_dict_set(&muxer_opts, sp.muxer_opt_key, sp.muxer_opt_value, 0);
        }
        */

        if (avformat_write_header(av_format_context, &muxer_opts) < 0)
        {
            printf("an error occurred when opening output file");
            return -1;
        }

        AVCodecContext *codec_context = avcodec_alloc_context3(av_format_context->video_codec);
        if (!codec_context)
        {
            printf("failed to allocated memory for AVCodecContext");
            return -1;
        };

        AVFrame *input_frame = av_frame_alloc();
        if (!input_frame)
        {
            printf("failed to allocated memory for AVFrame");
            return -1;
        }

        AVPacket *input_packet = av_packet_alloc();
        if (!input_packet)
        {
            printf("failed to allocated memory for AVPacket");
            return -1;
        }

        for (int i = 0; i < frames.size(); i++)
        {
            Variant v = frames[0];
            Image *image = Object::cast_to<Image>(v.operator Object *());

            image->convert(Image::FORMAT_RGBA8); // maybe we can use rbga32f directly

            input_frame->format = AV_PIX_FMT_RGBA;
            input_frame->width = image->get_width();
            input_frame->height = image->get_height();

            uint8_t *data;
            memcpy(data, image->get_data().read().ptr(), image->get_data().size());

            input_frame->data[0] = data;



            encode_video(av_format_context, codec_context, input_frame);

            Godot::print(String::num_int64(image->get_width()));
        }

        return 0;
    }


    int encode_video(AVFormatContext *format_context, AVCodecContext *codec_context, AVFrame *frame)
    {
        if (frame)
            frame->pict_type = AV_PICTURE_TYPE_NONE;

        AVPacket *output_packet = av_packet_alloc();
        if (!output_packet)
        {
            printf("could not allocate memory for output packet");
            return -1;
        }

        int response = avcodec_send_frame(codec_context, frame);

        while (response >= 0)
        {
            response = avcodec_receive_packet(codec_context, output_packet);
            if (response == AVERROR(EAGAIN) || response == AVERROR_EOF)
            {
                break;
            }
            else if (response < 0)
            {
                printf("Error while receiving packet from encoder: %s", av_err2str(response));
                return -1;
            }

            //output_packet->stream_index = decoder->video_index;
            output_packet->duration = 0;//encoder->video_avs->time_base.den / encoder->video_avs->time_base.num / decoder->video_avs->avg_frame_rate.num * decoder->video_avs->avg_frame_rate.den;

            // av_packet_rescale_ts(output_packet, decoder->video_avs->time_base, encoder->video_avs->time_base);

            response = av_interleaved_write_frame(format_context, output_packet);
            if (response != 0)
            {
                printf("Error %d while receiving packet from decoder: %s", response, av_err2str(response));
                return -1;
            }
        }
        av_packet_unref(output_packet);
        av_packet_free(&output_packet);
        return 0;
    }

    static void _register_methods()
    {
        register_method("get_data", &ExporterClass::method);
        register_method("export_frames", &ExporterClass::export_frames);

        /**
         * The line below is equivalent to the following GDScript export:
         *     export var _name = "ExporterClass"
         **/
        // register_property<ExporterClass, String>("base/name", &ExporterClass::_name, String("ExporterClass"));

        /** Alternatively, with getter and setter methods: */
        // register_property<ExporterClass, int>("base/value", &ExporterClass::set_value, &ExporterClass::get_value, 0);

        /** Registering a signal: **/
        // register_signal<ExporterClass>("signal_name");
        // register_signal<ExporterClass>("signal_name", "string_argument", GODOT_VARIANT_TYPE_STRING)
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
