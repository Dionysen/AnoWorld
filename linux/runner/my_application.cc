#include "my_application.h"

#include <flutter_linux/flutter_linux.h>

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  GtkWindow* window;
  FlMethodChannel* window_channel;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

static FlValue* current_geometry(GtkWindow* window) {
  gint x = 0;
  gint y = 0;
  gint width = 0;
  gint height = 0;
  gtk_window_get_position(window, &x, &y);
  gtk_window_get_size(window, &width, &height);
  FlValue* map = fl_value_new_map();
  fl_value_set_string_take(map, "x", fl_value_new_float(x));
  fl_value_set_string_take(map, "y", fl_value_new_float(y));
  fl_value_set_string_take(map, "width", fl_value_new_float(width));
  fl_value_set_string_take(map, "height", fl_value_new_float(height));
  fl_value_set_string_take(map, "maximized",
                           fl_value_new_bool(gtk_window_is_maximized(window)));
  return map;
}

static void notify_geometry(MyApplication* self) {
  if (self->window_channel == nullptr || self->window == nullptr) {
    return;
  }
  g_autoptr(FlValue) args = current_geometry(self->window);
  fl_method_channel_invoke_method(self->window_channel, "geometryChanged", args,
                                  nullptr, nullptr, nullptr);
}

static void on_maximized_changed(GObject* object,
                                 GParamSpec*,
                                 gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  if (self->window_channel == nullptr) {
    return;
  }
  gboolean maximized = gtk_window_is_maximized(GTK_WINDOW(object));
  g_autoptr(FlValue) args = fl_value_new_bool(maximized);
  fl_method_channel_invoke_method(self->window_channel, "windowState", args,
                                  nullptr, nullptr, nullptr);
  notify_geometry(self);
}

static gboolean on_configure_event(GtkWidget*,
                                   GdkEventConfigure*,
                                   gpointer user_data) {
  notify_geometry(MY_APPLICATION(user_data));
  return FALSE;
}

static void start_dragging(GtkWindow* window) {
  GdkWindow* gdk_window = gtk_widget_get_window(GTK_WIDGET(window));
  if (gdk_window == nullptr) {
    return;
  }
  GdkDisplay* display = gdk_window_get_display(gdk_window);
  GdkSeat* seat = gdk_display_get_default_seat(display);
  GdkDevice* pointer = gdk_seat_get_pointer(seat);
  if (pointer == nullptr) {
    return;
  }
  gint x = 0;
  gint y = 0;
  gdk_device_get_position(pointer, nullptr, &x, &y);
  gtk_window_begin_move_drag(window, 1, x, y, gtk_get_current_event_time());
}

static void window_method_cb(FlMethodChannel* /*channel*/,
                             FlMethodCall* method_call,
                             gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  const gchar* name = fl_method_call_get_name(method_call);
  GtkWindow* window = self->window;
  g_autoptr(FlValue) result = nullptr;

  if (g_strcmp0(name, "immersiveTitleBar") == 0) {
    result = fl_value_new_bool(TRUE);
  } else if (window == nullptr) {
    fl_method_call_respond_not_implemented(method_call, nullptr);
    return;
  } else if (g_strcmp0(name, "setMinimumSize") == 0) {
    FlValue* args = fl_method_call_get_args(method_call);
    gint width = 298;
    gint height = 116;
    if (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* width_value = fl_value_lookup_string(args, "width");
      FlValue* height_value = fl_value_lookup_string(args, "height");
      if (width_value != nullptr) {
        if (fl_value_get_type(width_value) == FL_VALUE_TYPE_FLOAT) {
          width = (gint)fl_value_get_float(width_value);
        } else if (fl_value_get_type(width_value) == FL_VALUE_TYPE_INT) {
          width = (gint)fl_value_get_int(width_value);
        }
      }
      if (height_value != nullptr) {
        if (fl_value_get_type(height_value) == FL_VALUE_TYPE_FLOAT) {
          height = (gint)fl_value_get_float(height_value);
        } else if (fl_value_get_type(height_value) == FL_VALUE_TYPE_INT) {
          height = (gint)fl_value_get_int(height_value);
        }
      }
    }
    GdkGeometry geometry = {};
    geometry.min_width = width;
    geometry.min_height = height;
    gtk_window_set_geometry_hints(window, nullptr, &geometry, GDK_HINT_MIN_SIZE);
  } else if (g_strcmp0(name, "getGeometry") == 0) {
    result = current_geometry(window);
  } else if (g_strcmp0(name, "setGeometry") == 0) {
    FlValue* args = fl_method_call_get_args(method_call);
    gint x = 0;
    gint y = 0;
    gint width = 1280;
    gint height = 720;
    gboolean maximized = FALSE;
    if (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* x_value = fl_value_lookup_string(args, "x");
      FlValue* y_value = fl_value_lookup_string(args, "y");
      FlValue* width_value = fl_value_lookup_string(args, "width");
      FlValue* height_value = fl_value_lookup_string(args, "height");
      FlValue* maximized_value = fl_value_lookup_string(args, "maximized");
      if (x_value != nullptr && fl_value_get_type(x_value) == FL_VALUE_TYPE_FLOAT) {
        x = (gint)fl_value_get_float(x_value);
      }
      if (y_value != nullptr && fl_value_get_type(y_value) == FL_VALUE_TYPE_FLOAT) {
        y = (gint)fl_value_get_float(y_value);
      }
      if (width_value != nullptr &&
          fl_value_get_type(width_value) == FL_VALUE_TYPE_FLOAT) {
        width = (gint)fl_value_get_float(width_value);
      }
      if (height_value != nullptr &&
          fl_value_get_type(height_value) == FL_VALUE_TYPE_FLOAT) {
        height = (gint)fl_value_get_float(height_value);
      }
      if (maximized_value != nullptr &&
          fl_value_get_type(maximized_value) == FL_VALUE_TYPE_BOOL) {
        maximized = fl_value_get_bool(maximized_value);
      }
    }
    if (gtk_window_is_maximized(window)) {
      gtk_window_unmaximize(window);
    }
    gtk_window_move(window, x, y);
    gtk_window_resize(window, width, height);
    if (maximized) {
      gtk_window_maximize(window);
    }
  } else if (g_strcmp0(name, "startDragging") == 0) {
    start_dragging(window);
  } else if (g_strcmp0(name, "toggleMaximize") == 0) {
    if (gtk_window_is_maximized(window)) {
      gtk_window_unmaximize(window);
    } else {
      gtk_window_maximize(window);
    }
  } else if (g_strcmp0(name, "minimize") == 0) {
    gtk_window_iconify(window);
  } else if (g_strcmp0(name, "close") == 0) {
    gtk_window_close(window);
  } else {
    fl_method_call_respond_not_implemented(method_call, nullptr);
    return;
  }

  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond_success(method_call, result, &error)) {
    g_warning("app/window respond failed: %s", error->message);
  }
}

static void set_window_icon(GtkWindow* window) {
  g_autofree gchar* exe = g_file_read_link("/proc/self/exe", nullptr);
  if (exe == nullptr) {
    return;
  }
  g_autofree gchar* dir = g_path_get_dirname(exe);
  g_autofree gchar* icon = g_build_filename(dir, "data", "app_icon.png", nullptr);
  GError* error = nullptr;
  if (!gtk_window_set_icon_from_file(window, icon, &error)) {
    g_clear_error(&error);
  }
}

static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  self->window = GTK_WINDOW(g_object_ref(window));

  // Replace the header bar with a zero-height title bar so Flutter owns the
  // caption while GTK keeps the resize frame.
  GtkWidget* title_bar = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
  gtk_widget_set_size_request(title_bar, -1, 0);
  gtk_window_set_titlebar(window, title_bar);
  gtk_window_set_title(window, "anoworld");
  set_window_icon(window);

  gtk_window_set_default_size(window, 1280, 720);
  {
    GdkGeometry geometry = {};
    geometry.min_width = 298;
    geometry.min_height = 116;
    gtk_window_set_geometry_hints(window, nullptr, &geometry, GDK_HINT_MIN_SIZE);
  }
  g_signal_connect(window, "notify::is-maximized",
                   G_CALLBACK(on_maximized_changed), self);
  g_signal_connect(window, "configure-event", G_CALLBACK(on_configure_event),
                   self);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->window_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)), "app/window",
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(self->window_channel,
                                            window_method_cb, self, nullptr);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

static void my_application_startup(GApplication* application) {
  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

static void my_application_shutdown(GApplication* application) {
  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  if (self->window != nullptr) {
    g_signal_handlers_disconnect_by_data(self->window, self);
    g_clear_object(&self->window);
  }
  g_clear_object(&self->window_channel);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
