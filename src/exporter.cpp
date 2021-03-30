extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/timestamp.h>
}

#include <string>

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

    void log(std::string text) {
      Godot::print(String(text.c_str()));
    }

    String method()
    {
        return "hello godot";
    }



    // a wrapper around a single output AVStream
    typedef struct OutputStream {
        AVStream *st;
        AVCodecContext *enc;

        /* pts of the next frame that will be generated */
        int64_t next_pts;
        int samples_count;

        AVFrame *frame;
        AVFrame *tmp_frame;

        float t, tincr, tincr2;

        struct SwsContext *sws_ctx;
        struct SwrContext *swr_ctx;
    } OutputStream;

    /* Add an output stream. */
    static void add_stream(OutputStream *ost, AVFormatContext *oc,
                           AVCodec **codec,
                           enum AVCodecID codec_id)
    {
        AVCodecContext *c;
        int i;

        /* find the encoder */
        *codec = avcodec_find_encoder(codec_id);
        if (!(*codec)) {
            fprintf(stderr, "Could not find encoder for '%s'\n",
                    avcodec_get_name(codec_id));
            exit(1);
        }

        ost->st = avformat_new_stream(oc, NULL);
        if (!ost->st) {
            fprintf(stderr, "Could not allocate stream\n");
            exit(1);
        }
        ost->st->id = oc->nb_streams-1;
        c = avcodec_alloc_context3(*codec);
        if (!c) {
            fprintf(stderr, "Could not alloc an encoding context\n");
            exit(1);
        }
        ost->enc = c;

        switch ((*codec)->type) {
        case AVMEDIA_TYPE_AUDIO:
            c->sample_fmt  = (*codec)->sample_fmts ?
                (*codec)->sample_fmts[0] : AV_SAMPLE_FMT_FLTP;
            c->bit_rate    = 64000;
            c->sample_rate = 44100;
            if ((*codec)->supported_samplerates) {
                c->sample_rate = (*codec)->supported_samplerates[0];
                for (i = 0; (*codec)->supported_samplerates[i]; i++) {
                    if ((*codec)->supported_samplerates[i] == 44100)
                        c->sample_rate = 44100;
                }
            }
            c->channels        = av_get_channel_layout_nb_channels(c->channel_layout);
            c->channel_layout = AV_CH_LAYOUT_STEREO;
            if ((*codec)->channel_layouts) {
                c->channel_layout = (*codec)->channel_layouts[0];
                for (i = 0; (*codec)->channel_layouts[i]; i++) {
                    if ((*codec)->channel_layouts[i] == AV_CH_LAYOUT_STEREO)
                        c->channel_layout = AV_CH_LAYOUT_STEREO;
                }
            }
            c->channels        = av_get_channel_layout_nb_channels(c->channel_layout);
            ost->st->time_base = (AVRational){ 1, c->sample_rate };
            break;

        case AVMEDIA_TYPE_VIDEO:
            c->codec_id = codec_id;

            c->bit_rate = 400000;
            /* Resolution must be a multiple of two. */
            c->width    = 352;
            c->height   = 288;
            /* timebase: This is the fundamental unit of time (in seconds) in terms
             * of which frame timestamps are represented. For fixed-fps content,
             * timebase should be 1/framerate and timestamp increments should be
             * identical to 1. */
            ost->st->time_base = (AVRational){ 1, 30 };
            c->time_base       = ost->st->time_base;

            c->gop_size      = 12; /* emit one intra frame every twelve frames at most */
            c->pix_fmt       = AV_PIX_FMT_YUV420P;
            if (c->codec_id == AV_CODEC_ID_MPEG2VIDEO) {
                /* just for testing, we also add B-frames */
                c->max_b_frames = 2;
            }
            if (c->codec_id == AV_CODEC_ID_MPEG1VIDEO) {
                /* Needed to avoid using macroblocks in which some coeffs overflow.
                 * This does not happen with normal video, it just happens here as
                 * the motion of the chroma plane does not match the luma plane. */
                c->mb_decision = 2;
            }
            break;

        default:
            break;
        }

        /* Some formats want stream headers to be separate. */
        if (oc->oformat->flags & AVFMT_GLOBALHEADER)
            c->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
    }

    static void open_video(AVFormatContext *oc, AVCodec *codec, OutputStream *ost, AVDictionary *opt_arg)
    {
        int ret;
        AVCodecContext *c = ost->enc;
        AVDictionary *opt = NULL;

        av_dict_copy(&opt, opt_arg, 0);

        /* open the codec */
        ret = avcodec_open2(c, codec, &opt);
        av_dict_free(&opt);
        if (ret < 0) {
            fprintf(stderr, "Could not open video codec: %d\n", ret);
            exit(1);
        }

        /* allocate and init a re-usable frame */
        /*
        ost->frame = alloc_picture(c->pix_fmt, c->width, c->height);
        if (!ost->frame) {
            fprintf(stderr, "Could not allocate video frame\n");
            exit(1);
        }
        */

        /* If the output format is not YUV420P, then a temporary YUV420P
         * picture is needed too. It is then converted to the required
         * output format. */
        /*
        ost->tmp_frame = NULL;
        if (c->pix_fmt != AV_PIX_FMT_YUV420P) {
            ost->tmp_frame = alloc_picture(AV_PIX_FMT_YUV420P, c->width, c->height);
            if (!ost->tmp_frame) {
                fprintf(stderr, "Could not allocate temporary picture\n");
                exit(1);
            }
        }
        */

        /* copy the stream parameters to the muxer */
        ret = avcodec_parameters_from_context(ost->st->codecpar, c);
        if (ret < 0) {
            fprintf(stderr, "Could not copy the stream parameters\n");
            exit(1);
        }
    }


    int export_frames(Array frames, String export_filename)
    {


        AVFormatContext *av_format_context;
        AVCodec *video_codec;
        OutputStream video_stream = { 0 };
        int have_video = 0;
        AVDictionary *opt = NULL;

        char *filename = export_filename.alloc_c_string();
        Godot::print(filename);

        avformat_alloc_output_context2(&av_format_context, NULL, NULL, filename);
        if (!av_format_context)
        {
            log("could not allocate memory for output format");
            return -1;
        }

        /* Add the audio and video streams using the default format codecs
         * and initialize the codecs. */
        if (av_format_context->oformat->video_codec != AV_CODEC_ID_NONE) {
            add_stream(&video_stream, av_format_context, &video_codec, av_format_context->oformat->video_codec);
            have_video = 1;
        }
        /*
        if (fmt->audio_codec != AV_CODEC_ID_NONE) {
            add_stream(&audio_st, oc, &audio_codec, fmt->audio_codec);
            have_audio = 1;
            encode_audio = 1;
        }
        */


        av_dump_format(av_format_context, 0, filename, 1);

        if (have_video)
          open_video(av_format_context, video_codec, &video_stream, opt);

        log("open 1");
        if (!(av_format_context->oformat->flags & AVFMT_NOFILE))
        {
            log("open outputfile");
            if (avio_open(&av_format_context->pb, filename, AVIO_FLAG_WRITE) < 0)
            {
                log("could not open the output file");
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

        Godot::print("write header");
        if (avformat_write_header(av_format_context, &muxer_opts) < 0)
        {
            log("an error occurred when opening output file");
            return -1;
        }

        AVCodecContext *codec_context = avcodec_alloc_context3(av_format_context->video_codec);
        if (!codec_context)
        {
            log("failed to allocated memory for AVCodecContext");
            return -1;
        };

        AVFrame *input_frame = av_frame_alloc();
        if (!input_frame)
        {
            log("failed to allocated memory for AVFrame");
            return -1;
        }

        AVPacket *input_packet = av_packet_alloc();
        if (!input_packet)
        {
            log("failed to allocated memory for AVPacket");
            return -1;
        }

        log("frames");
        for (int i = 0; i < frames.size(); i++)
        {
            Variant v = frames[0];
            Image *image = Object::cast_to<Image>(v.operator Object *());

            log("convert");
            image->convert(Image::FORMAT_RGB8); // maybe we can use rbga32f directly

            input_frame = av_frame_alloc();

            input_frame->format = AV_PIX_FMT_YUV420P;
            input_frame->width = image->get_width();
            input_frame->height = image->get_height();


            /* allocate the buffers for the frame data */
            int ret = av_frame_get_buffer(input_frame, 0);
            if (ret < 0) {
                fprintf(stderr, "Could not allocate frame data.\n");
                exit(1);
            }


            log("copy");
            uint8_t *data = (uint8_t*)malloc(image->get_data().size() * sizeof(uint8_t));
            memcpy(data, image->get_data().read().ptr(), image->get_data().size());

            log("set data");
            input_frame->data[0] = data;



            log("encode");
            memcpy(data, image->get_data().read().ptr(), image->get_data().size());
            encode_video(av_format_context, codec_context, input_frame);

            Godot::print(String::num_int64(image->get_width()));
        }


        /* Write the trailer, if any. The trailer must be written before you
         * close the CodecContexts open when you wrote the header; otherwise
         * av_write_trailer() may try to use memory that was freed on
         * av_codec_close(). */
        av_write_trailer(av_format_context);

        if (!(av_format_context->oformat->flags & AVFMT_NOFILE))
            /* Close the output file. */
            avio_closep(&av_format_context->pb);

        /* free the stream */
        avformat_free_context(av_format_context);
        
        return 0;
    }


    int encode_video(AVFormatContext *format_context, AVCodecContext *codec_context, AVFrame *frame)
    {
        if (frame)
            frame->pict_type = AV_PICTURE_TYPE_NONE;

        AVPacket *output_packet = av_packet_alloc();
        if (!output_packet)
        {
            log("could not allocate memory for output packet");
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
                printf("Error while receiving packet from encoder: %d", response);
                return -1;
            }

            //output_packet->stream_index = decoder->video_index;
            output_packet->duration = 0;//encoder->video_avs->time_base.den / encoder->video_avs->time_base.num / decoder->video_avs->avg_frame_rate.num * decoder->video_avs->avg_frame_rate.den;

            // av_packet_rescale_ts(output_packet, decoder->video_avs->time_base, encoder->video_avs->time_base);

            response = av_interleaved_write_frame(format_context, output_packet);
            if (response != 0)
            {
                printf("Error %d while receiving packet from decoder: %d", response, response);
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
