/*
 * Copyright 2011-2014 Jiří Janoušek <janousek.jiri@gmail.com>
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

/**
 * Manages multimedia keys
 */
public class MediaKeys: GLib.Object, MediaKeysInterface
{
	public bool managed {get; protected set; default=false;}
	private string app_id;
	private XKeyGrabber key_grabber;
	private GnomeMediaKeys? gnome_media_keys = null;
	private HashTable<string, string> keymap;
	
	public MediaKeys(string app_id, XKeyGrabber key_grabber)
	{
		this.app_id = app_id;
		this.key_grabber = key_grabber;
		keymap = new HashTable<string, string>(str_hash, str_equal);
		keymap["XF86AudioPlay"] = "Play";
		keymap["XF86AudioPause"] = "Pause";
		keymap["XF86AudioStop"] = "Stop";
		keymap["XF86AudioPrev"] = "Previous";
		keymap["XF86AudioNext"] = "Next";
//~ 		keymap["<Shift><Super>t"] = "Play";
//~ 		keymap["<Shift><Super>n"] = "Next";
	}
	
	~MediaKeys()
	{
		unmanage();
	}
	
	public void manage()
	{
		if (managed)
			return;
		
		Bus.watch_name(BusType.SESSION, "org.gnome.SettingsDaemon",
			BusNameWatcherFlags.NONE, gnome_settings_appeared, gnome_settings_vanished);
		managed = true;
	}
	
	public void unmanage()
	{
		if (!managed)
			return;
		
		if (gnome_media_keys == null)
		{
			ungrab_media_keys();
			return;
		}
		
		try
		{
			gnome_media_keys.release_media_player_keys(app_id);
			gnome_media_keys.media_player_key_pressed.disconnect(on_media_key_pressed);
			gnome_media_keys = null;
		}
		catch (IOError e)
		{
			warning("Unable to get proxy for GNOME Media keys: %s", e.message);
			gnome_media_keys = null;
		}
		
		managed = false;
	}
	
	/**
	 * Use GNOME settings daemon to control multimedia keys
	 */
	private void gnome_settings_appeared(DBusConnection conn, string name, string owner)
	{
		debug("GNOME settings daemon appeared: %s, %s", name, owner);
		ungrab_media_keys();
		if (!grab_gnome_media_keys())
		{
			gnome_media_keys = null;
			grab_media_keys();
		}
	}
	
	private bool grab_gnome_media_keys()
	{
		try
		{
			gnome_media_keys = Bus.get_proxy_sync(BusType.SESSION,
			"org.gnome.SettingsDaemon",
			"/org/gnome/SettingsDaemon/MediaKeys");
			/* Vala includes "return false" if DBus method call fails! */
			gnome_media_keys.grab_media_player_keys(app_id, 0);
			gnome_media_keys.media_player_key_pressed.connect(on_media_key_pressed);
			return true;
			
		}
		catch (IOError e)
		{
			warning("Unable to get proxy for GNOME Media keys: %s", e.message);
			return false;
		}
	}
	
	private void gnome_settings_vanished(DBusConnection conn, string name)
	{
		debug("GNOME settings daemon vanished: %s", name);
		if (gnome_media_keys != null)
			gnome_media_keys.media_player_key_pressed.disconnect(on_media_key_pressed);
		gnome_media_keys = null;
		grab_media_keys();
	}
	
	private void on_media_key_pressed(string app_name, string key)
	{
		debug("Media key pressed: %s, %s", app_name, key);
		if (app_name != app_id)
			return;
		media_key_pressed(key);
	}
	
	/**
	 * Fallback to use Xorg keybindings
	 */
	private void grab_media_keys()
	{
		var keys = keymap.get_keys();
		foreach (var key in keys)
			key_grabber.grab(key, true);
		key_grabber.keybinding_pressed.connect(on_keybinding_pressed);
	}
	
	private void ungrab_media_keys()
	{
		key_grabber.keybinding_pressed.disconnect(on_keybinding_pressed);
		var keys = keymap.get_keys();
		foreach (var key in keys)
			key_grabber.ungrab(key);
	}
	
	private void on_keybinding_pressed(string accelerator, uint32 time)
	{
		var name = keymap[accelerator];
		if (name != null)
			media_key_pressed(name);
	}
}

[DBus(name = "org.gnome.SettingsDaemon.MediaKeys")]
public interface GnomeMediaKeys: Object
{
	public abstract void grab_media_player_keys(string app, uint32 time) throws IOError;
	public abstract void release_media_player_keys(string app) throws IOError;
	public signal void media_player_key_pressed(string app, string key);
}

} // namespace Nuvola
