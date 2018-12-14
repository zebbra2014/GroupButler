local Message = {}
local message = Message

local _p = setmetatable({}, {__mode = "k"}) -- weak table storing all private attributes

function Message:new(obj, update_obj)
	_p[obj] = {
		api = update_obj.api,
		db = update_obj.db,
		u = update_obj.u,
	}
	setmetatable(obj, {__index = self})
	return obj
end

local function is_from_admin(self)
	if self.chat.type == "private" -- This should never happen but...
	or not (self.chat.id < 0 or self.target_id)
	or not self.from then
		return false
	end
	return _p[self].u:is_admin(self.target_id or self.chat.id, self.from.id)
end

function message:is_from_admin()
	if self._cached_is_from_admin == nil then
		self._cached_is_from_admin = is_from_admin(self)
	end
	return self._cached_is_from_admin
end

local function msg_type(self)
	-- TODO: update database to use "animation" instead of "gif"
	if self.animation then
		return "gif"
	end
	local media_types = {
		"audio", --[["animation",]] "contact", "document", "game", "location", "photo", "sticker", "venue", "video",
		"video_note", "voice",
	}
	for _, v in pairs(media_types) do
		if self[v] then
			return v
		end
	end
	if self.entities then
		for _, entity in pairs(self.entities) do
			if entity.type == "url" or entity.type == "text_link" then
				return "link"
			end
		end
	end
	return "text"
end

function message:type()
	if self._cached_type == nil then
		self._cached_type = msg_type(self)
	end
	return self._cached_type
end

local function get_file_id(self)
	if self.animation then -- TODO: remove this once db migration for gif messages has been completed
		return self.animation.file_id
	end
	if self.photo then
		return self.photo[#self.photo].file_id
	end
	if self[self:type()] and self[self:type()].file_id then
		return self[self:type()].file_id
	end
	return false -- The message has no media file_id
end

function message:get_file_id()
	if self._cached_get_file_id == nil then
		self._cached_get_file_id = get_file_id(self)
	end
	return self._cached_get_file_id
end

function message:send_reply(text, parse_mode, disable_web_page_preview, disable_notification, reply_markup)
	return _p[self].api:sendMessage(self.chat.id, text, parse_mode, disable_web_page_preview, disable_notification,
		self.message_id, reply_markup)
end

function Message:cacheChatMember()
	if not self.chat
	or not self.from then
		return
	end
	-- Just in case...
	self.chat:cache()
	self.from:cache()
	local chat_member = {
		user = self.from
	}
	_p[self].db:cacheChatMember(self.chat, chat_member)
end

return Message
