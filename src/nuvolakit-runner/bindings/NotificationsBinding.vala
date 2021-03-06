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

public class Nuvola.NotificationsBinding: ObjectBinding<NotificationsInterface>
{
	public NotificationsBinding(Diorite.Ipc.MessageServer server, WebWorker web_worker)
	{
		base(server, web_worker, "Nuvola.Notifications");
	}
	
	protected override void bind_methods()
	{
		bind("showNotification", handle_show_notification);
		bind("isPersistenceSupported", handle_is_persistence_supported);
	}
	
	private Variant? handle_show_notification(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		check_not_empty();
		Diorite.Ipc.MessageServer.check_type_str(data, "(ssssbs)");
		string summary = null;
		string body = null;
		string icon_name = null;
		string icon_path = null;
		bool force = false;
		string? category = null;
		data.get("(ssssbs)", &summary, &body, &icon_name, &icon_path, &force, &category);
		
		foreach (var object in objects)
			if (object.show_anonymous(summary, body, icon_name, icon_path, force, category))
				break;
		
		return null;
	}
	
	private Variant? handle_is_persistence_supported(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		check_not_empty();
		Diorite.Ipc.MessageServer.check_type_str(data, null);
		bool supported = false;
		foreach (var object in objects)
			if (object.is_persistence_supported(ref supported))
				break;
		
		return new Variant.boolean(supported);
	}
}
