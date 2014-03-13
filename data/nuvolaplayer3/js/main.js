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

(function(Nuvola)
{

Nuvola.formatRegExp = new RegExp("{-?[0-9]+}", "g");
Nuvola.format = function ()
{
	var args = arguments;
	return args[0].replace(this.formatRegExp, function (item)
	{
		var index = parseInt(item.substring(1, item.length - 1));
		if (index > 0)
			return typeof args[index] !== 'undefined' ? args[index] : "";
		else if (index === -1)
			return "{";
		else if (index === -2)
			return "}";
		return "";
	});
};

Nuvola.makeSignaling = function(obj_proto)
{
	obj_proto.registerSignals = function(signals)
	{
		if (this.signals === undefined)
			this.signals = {};
		
		var size = signals.length;
		for (var i = 0; i < size; i++)
		{
			this.signals[signals[i]] = [];
		}
	}
	
	obj_proto.connect = function(name, object, handlerName)
	{
		var handlers = this.signals[name];
		if (handlers === undefined)
			throw new Error("Unknown signal '" + name + "'.");
		handlers.push([object, handlerName]);
	}
	
	obj_proto.disconnect = function(name, object, handlerName)
	{
		var handlers = this.signals[name];
		if (handlers === undefined)
			throw new Error("Unknown signal '" + name + "'.");
		var size = handlers.length;
		for (var i = 0; i < size; i++)
		{
			var handler = handlers[i];
			if (handler[0] === object && handler[1] === handlerName)
			{
				handlers.splice(i, 1);
				break;
			}
		}
	}
	
	obj_proto.emit = function(name)
	{
		var handlers = this.signals[name];
		if (handlers === undefined)
			throw new Error("Unknown signal '" + name + "'.");
		var size = handlers.length;
		var args = [this];
		for (var i = 1; i < arguments.length; i++)
			args.push(arguments[i]);
		
		for (var i = 0; i < size; i++)
		{
			var handler = handlers[i];
			var object = handler[0];
			object[handler[1]].apply(object, args);
		}
	}
}

Nuvola.makeSignaling(Nuvola);
Nuvola.registerSignals(["home-page"]);

Nuvola.Notification =
{
	update: function(title, text, iconName, iconURL)
	{
		Nuvola.sendMessage("Nuvola.Notification.update", title, text, iconName || "", iconURL || "");
	},
	
	show: function()
	{
		Nuvola.sendMessage("Nuvola.Notification.show");
	},
}

Nuvola.TrayIcon =
{
	setTooltip: function(tooltip)
	{
		Nuvola.sendMessage("Nuvola.TrayIcon.setTooltip", tooltip || "");
	},
	
	setActions: function(actions)
	{
		Nuvola.sendMessage("Nuvola.TrayIcon.setActions", actions);
	},
}

Nuvola.Actions =
{
	addAction: function(group, scope, name, label, mnemo_label, icon, keybinding)
	{
		Nuvola.sendMessage("Nuvola.Actions.addAction", group, scope, name, label || "", mnemo_label || "", icon || "", keybinding || "");
	},
	
	debug: function(arg1, arg2)
	{
		console.log(arg1 + ", " + arg2);
	}
}

Nuvola.makeSignaling(Nuvola.Actions);
Nuvola.Actions.registerSignals(["action-activated"]);
Nuvola.Actions.connect("action-activated", Nuvola.Actions, "debug");

Nuvola.Player = 
{
	ACTION_PLAY: "play",
	ACTION_TOGGLE_PLAY: "toggle-play",
	ACTION_PAUSE: "pause",
	ACTION_STOP: "stop",
	ACTION_PREV_SONG: "prev-song",
	ACTION_NEXT_SONG: "next-song",
	STATE_UNKNOWN: 0,
	STATE_PAUSED: 1,
	STATE_PLAYING: 2,
	
	_initialized: false,
	state: 0,
	song: null,
	artist: null,
	album: null,
	artwork: null,
	prevData: {},
	
	init: function()
	{
		Nuvola.Actions.addAction("playback", "win", this.ACTION_PLAY, "Play", null, "media-playback-start", null);
		Nuvola.Actions.addAction("playback", "win", this.ACTION_PAUSE, "Pause", null, "media-playback-pause", null);
		Nuvola.Actions.addAction("playback", "win", this.ACTION_TOGGLE_PLAY, "Toggle play/pause", null, null, null);
		Nuvola.Actions.addAction("playback", "win", this.ACTION_STOP, "Stop", null, "media-playback-stop", null);
		Nuvola.Actions.addAction("playback", "win", this.ACTION_PREV_SONG, "Previous song", null, "media-skip-backward", null);
		Nuvola.Actions.addAction("playback", "win", this.ACTION_NEXT_SONG, "Next song", null, "media-skip-forward", null);
	},
	
	update: function()
	{
		if (!this._initialized)
		{
			Nuvola.Actions.connect("action-activated", this, "onActionActivated");
			this._initialized = true;
		}
		
		var changed = [];
		var keys = ["song", "artist", "album", "artwork", "state"];
		for (var i = 0; i < keys.length; i++)
		{
			var key = keys[i];
			if (this.prevData[key] !== this[key])
			{
				this.prevData[key] = this[key];
				changed.push(key);
			}
		}
		
		if (!changed.length)
			return;
		
		if (this.song)
		{
			var title = this.song;
			var message;
			if (!this.artist && !this.album)
				message = "by unknown artist";
			else if(!this.artist)
				message = Nuvola.format("from {1}", this.album);
			else if(!this.album)
				message = Nuvola.format("by {1}", this.artist);
			else
				message = Nuvola.format("by {1} from {2}", this.artist, this.album);
			
			Nuvola.Notification.update(title, message, "nuvolaplayer", null);
			Nuvola.Notification.show();
			
			if (this.artist)
				var tooltip = Nuvola.format("{1} by {2}", this.song, this.artist);
			else
				var tooltip = this.song;
			
			Nuvola.TrayIcon.setTooltip(tooltip);
		}
		else
		{
			Nuvola.TrayIcon.setTooltip("Nuvola Player");
		}
		
		if (this.state === this.STATE_PLAYING || this.state === this.STATE_PAUSED)
			Nuvola.TrayIcon.setActions([this.state === this.STATE_PAUSED ? this.ACTION_PLAY : this.ACTION_PAUSE, this.ACTION_PREV_SONG, this.ACTION_NEXT_SONG, "quit"]);
		else
			Nuvola.TrayIcon.setActions(["quit"]);
	},
	
	onActionActivated: function(object, name)
	{
		switch (name)
		{
		case this.ACTION_PLAY:
		case this.ACTION_TOGGLE_PLAY:
		case this.ACTION_PAUSE:
		case this.ACTION_STOP:
		case this.ACTION_PREV_SONG:
		case this.ACTION_NEXT_SONG:
			alert(name);
			break;
		}
	}
};

})(this);  // function(Nuvola)