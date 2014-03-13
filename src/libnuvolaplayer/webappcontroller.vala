/*
 * Copyright 2014 Jiří Janoušek <janousek.jiri@gmail.com>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met: 
 * 
 * 1. Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer. 
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution. 
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

namespace Nuvola
{

namespace ConfigKey
{
	public const string WINDOW_X = "nuvola.window.x";
	public const string WINDOW_Y = "nuvola.window.y";
	public const string WINDOW_WIDTH = "nuvola.window.width";
	public const string WINDOW_HEIGHT = "nuvola.window.height";
	public const string WINDOW_MAXIMIZED = "nuvola.window.maximized";
}

public class WebAppController : Diorite.Application
{
	public WebAppWindow? main_window {get; private set; default = null;}
	public Diorite.Storage? storage {get; private set; default = null;}
	public Diorite.ActionsRegistry? actions {get; private set; default = null;}
	public WebApp web_app {get; private set;}
	public WebEngine web_engine {get; private set;}
	public weak Gtk.Settings gtk_settings {get; private set;}
	public Config config {get; private set;}
	public ExtensionsManager extensions {get; private set;}
	private static const int MINIMAL_REMEMBERED_WINDOW_SIZE = 300;
	private uint configure_event_cb_id = 0;
	
	public WebAppController(Diorite.Storage? storage, WebApp web_app)
	{
		var app_id = web_app.meta.id;
		base("%sX%s".printf(Nuvola.get_unique_name(), app_id),
		"%s - %s".printf(web_app.meta.name, Nuvola.get_display_name()),
		"%s-%s.desktop".printf(Nuvola.get_appname(), app_id),
		"%s-%s".printf(Nuvola.get_appname(), app_id));
		icon = Nuvola.get_app_icon();
		version = Nuvola.get_version();
		this.storage = storage;
		this.web_app = web_app;
	}
	
	public override void activate()
	{
		if (main_window == null)
			start();
		main_window.present();
	}
	
	private void start()
	{
		gtk_settings = Gtk.Settings.get_default();
		config = new Config(web_app.user_config_dir.get_child("config.json"));
		actions = new Diorite.ActionsRegistry(this, null);
		append_actions();
		main_window = new WebAppWindow(this);
		fatal_error.connect(on_fatal_error);
		show_error.connect(on_show_error);
		web_engine = new WebEngine(this, web_app, config);
		web_engine.message_received.connect(on_message_received);
		var widget = web_engine.widget;
		widget.hexpand = widget.vexpand = true;
		if (!web_engine.load())
			return;
		main_window.grid.add(widget);
		
		int x = (int) config.get_int(ConfigKey.WINDOW_X, -1);
		int y = (int) config.get_int(ConfigKey.WINDOW_Y, -1);
		if (x >= 0 && y >= 0)
			main_window.move(x, y);
			
		int w = (int) config.get_int(ConfigKey.WINDOW_WIDTH);
		int h = (int) config.get_int(ConfigKey.WINDOW_HEIGHT);
		main_window.resize(w > MINIMAL_REMEMBERED_WINDOW_SIZE ? w: 1010, h > MINIMAL_REMEMBERED_WINDOW_SIZE ? h : 600);
		
		if (config.get_bool(ConfigKey.WINDOW_MAXIMIZED, false))
			main_window.maximize();
		
		main_window.show_all();
		main_window.window_state_event.connect(on_window_state_event);
		main_window.configure_event.connect(on_configure_event);
		load_extensions();
	}
	
	private void append_actions()
	{
		Diorite.Action[] actions_spec = {
		//          Action(group, scope, name, label?, mnemo_label?, icon?, keybinding?, callback?)
		new Diorite.Action("main", "app", Actions.QUIT, "Quit", "_Quit", "application-exit", "<ctrl>Q", do_quit)
		};
		actions.add_actions(actions_spec);
		
	}
	
	private void do_quit()
	{
		quit();
	}
	
	private void load_extensions()
	{
		extensions = new ExtensionsManager(this);
		var available_extensions = extensions.available_extensions;
		foreach (var key in available_extensions.get_keys())
			if (config.get_bool(ConfigKey.EXTENSION_ENABLED.printf(key), available_extensions.lookup(key).autoload))
				extensions.load(key);
	}
	
	private void on_fatal_error(string title, string message)
	{
		var dialog = new Diorite.ErrorDialog(title, message + "\n\nThe application has reached an inconsistent state and will quit for that reason.");
		dialog.run();
		dialog.destroy();
	}
	
	private void on_show_error(string title, string message)
	{
		var dialog = new Diorite.ErrorDialog(title, message + "\n\nThe application might not function properly.");
		dialog.run();
		dialog.destroy();
	}
	
	private bool on_window_state_event(Gdk.EventWindowState event)
	{
		bool m = (event.new_window_state & Gdk.WindowState.MAXIMIZED) != 0;
		config.set_bool(ConfigKey.WINDOW_MAXIMIZED, m);
		config.save();
		return false;
	} 
	
	private bool on_configure_event(Gdk.EventConfigure event)
	{
		if (configure_event_cb_id != 0)
			Source.remove(configure_event_cb_id);
		configure_event_cb_id = Timeout.add(200, on_configure_event_cb);
		return false;
	}
	
	private bool on_configure_event_cb()
	{
		configure_event_cb_id = 0;
		if (!main_window.maximized)
		{
			int x;
			int y;
			int width;
			int height;
			main_window.get_position (out x, out y);
			main_window.get_size(out width, out height);
			config.set_int(ConfigKey.WINDOW_X, (int64) x);
			config.set_int(ConfigKey.WINDOW_Y, (int64) y);
			config.set_int(ConfigKey.WINDOW_WIDTH, (int64) width);
			config.set_int(ConfigKey.WINDOW_HEIGHT, (int64) height);
			config.save();
		}
		return false;
	}
	
	private void on_message_received(WebEngine engine, string name, Variant? data)
	{
		if (name == "Nuvola.Actions.addAction")
		{
			string group = null;
			string scope = null;
			string action_name = null;
			string? label = null;
			string? mnemo_label = null;
			string? icon = null;
			string? keybinding = null;
			if (data != null)
			{
				data.get("(sssssss)", &group, &scope, &action_name, &label, &mnemo_label, &icon, &keybinding);
				if (label == "")
					label = null;
				if (mnemo_label == "")
					mnemo_label = null;
				if (icon == "")
					icon = null;
				if (keybinding == "")
					keybinding = null;
				var action = new Diorite.Action(group, scope, action_name, label, mnemo_label, icon, keybinding, null);
				action.activated.connect(on_custom_action_activated);
				actions.add_action(action);
			}
			web_engine.message_handled();
		}
	}
	
	private void on_custom_action_activated(Diorite.Action action, Variant? parameter)
	{
		try
		{
			web_engine.call_function("Nuvola.Actions.emit", new Variant("(ss)", "action-activated", action.name));
		}
		catch (Diorite.Ipc.MessageError e)
		{
			warning("Communication failed: %s", e.message);
		}
	}
}

} // namespace Nuvola