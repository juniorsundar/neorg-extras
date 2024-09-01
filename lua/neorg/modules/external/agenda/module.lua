local neorg = require("neorg.core")
local module = neorg.modules.create("external.agenda")

module.setup = function()
	return {
		success = true,
		requires = {
			"core.neorgcmd",
			"core.integrations.treesitter",
			"external.many-mans",
		},
	}
end

module.load = function()
	module.required["core.neorgcmd"].add_commands_from_table({
		["agenda"] = {
			args = 1,
			subcommands = {
				["page"] = {
					min_args = 1,
					max_args = 8,
					complete = {
						{
							"done",
							"pending",
							"undone",
							"hold",
							"important",
							"cancelled",
							"recurring",
							"ambiguous",
						},
						{
							"done",
							"pending",
							"undone",
							"hold",
							"important",
							"cancelled",
							"recurring",
							"ambiguous",
						},
						{
							"done",
							"pending",
							"undone",
							"hold",
							"important",
							"cancelled",
							"recurring",
							"ambiguous",
						},
						{
							"done",
							"pending",
							"undone",
							"hold",
							"important",
							"cancelled",
							"recurring",
							"ambiguous",
						},
						{
							"done",
							"pending",
							"undone",
							"hold",
							"important",
							"cancelled",
							"recurring",
							"ambiguous",
						},
						{
							"done",
							"pending",
							"undone",
							"hold",
							"important",
							"cancelled",
							"recurring",
							"ambiguous",
						},
						{
							"done",
							"pending",
							"undone",
							"hold",
							"important",
							"cancelled",
							"recurring",
							"ambiguous",
						},
						{
							"done",
							"pending",
							"undone",
							"hold",
							"important",
							"cancelled",
							"recurring",
							"ambiguous",
						},
					},
					name = "external.agenda.page",
				},
				["day"] = {
					args = 0,
					name = "external.agenda.day",
				},
				["tag"] = {
					args = 0,
					name = "external.agenda.tag",
				},
			},
		},
	})
end

module.events.subscribed = {
	["core.neorgcmd"] = {
		["external.agenda.page"] = true,
		["external.agenda.day"] = true,
		["external.agenda.tag"] = true,
	},
}

module.private = {
	-- Sort function specifically for today's tasks by hour and minute
	sort_today_tasks = function(a, b)
		local a_time = os.time({
			year = tonumber(a.deadline.year) or 2024,
			month = tonumber(a.deadline.month) or 8,
			day = tonumber(a.deadline.day) or 12,
			hour = tonumber(a.deadline.hour) or 0,
			min = tonumber(a.deadline.minute) or 0,
			sec = 0,
		})
		local b_time = os.time({
			year = tonumber(b.deadline.year) or 2024,
			month = tonumber(b.deadline.month) or 8,
			day = tonumber(b.deadline.day) or 12,
			hour = tonumber(b.deadline.hour) or 0,
			min = tonumber(b.deadline.minute) or 0,
			sec = 0,
		})
		return a_time < b_time
	end,

	-- Sort function to prioritize by time to deadline and priority
	sort_by_time_and_priority = function(a, b)
		local current_time = os.time()
		local time_a = os.time({
			year = tonumber(a.deadline.year) or 2024,
			month = tonumber(a.deadline.month) or 8,
			day = tonumber(a.deadline.day) or 12,
			hour = tonumber(a.deadline.hour) or 0,
			min = tonumber(a.deadline.minute) or 0,
			sec = 0,
		}) - current_time
		local time_b = os.time({
			year = tonumber(b.deadline.year) or 2024,
			month = tonumber(b.deadline.month) or 8,
			day = tonumber(b.deadline.day) or 12,
			hour = tonumber(b.deadline.hour) or 0,
			min = tonumber(b.deadline.minute) or 0,
			sec = 0,
		}) - current_time

		if time_a ~= time_b then
			return time_a < time_b
		end

		local priority_a = a.priority or "Z"
		local priority_b = b.priority or "Z"
		return priority_a < priority_b
	end,

	--- Due to repetition of overdue, this_week and next_week lines,
	--- we create a function that can repeatedly generate the buffer lines.
	--- @param task table
	--- @param curr_time integer
	--- @return table
	format_task_line = function(task, curr_time)
		local time_str = ""
		if task.deadline then
			-- Define the task deadline time
			local task_time = os.time({
				year = tonumber(task.deadline.year) or 2024,
				month = tonumber(task.deadline.month) or 8,
				day = tonumber(task.deadline.day) or 12,
			})

			-- Flag to check if the task deadline is today
			local is_today = (task.deadline.year - tonumber(os.date("%Y")) == 0)
				and (task.deadline.month - tonumber(os.date("%m")) == 0)
				and (task.deadline.day - tonumber(os.date("%d")) == 0)

			local years_diff = 0
			local months_diff = 0
			local days_diff = 0

			if is_today then
				time_str = "*"
					.. "{:"
					.. task.filename
					.. ":"
					.. string.gsub(task.task, "%b()", "")
					.. "}["
					.. task.deadline.hour
					.. ":"
					.. task.deadline.minute
					.. "]*"
			else
				-- Calculate differences
				if task_time > curr_time then
					years_diff = os.date("*t", task_time).year - os.date("*t", curr_time).year
					months_diff = os.date("*t", task_time).month - os.date("*t", curr_time).month
					days_diff = os.date("*t", task_time).day - os.date("*t", curr_time).day
				else
					years_diff = os.date("*t", curr_time).year - os.date("*t", task_time).year
					months_diff = os.date("*t", curr_time).month - os.date("*t", task_time).month
					days_diff = os.date("*t", curr_time).day - os.date("*t", task_time).day + 1 -- Difference offset
				end

				-- Handle negative days
				if days_diff < 0 then
					months_diff = months_diff - 1
					local previous_month_time = os.time({
						year = os.date("*t", task_time).year,
						month = os.date("*t", task_time).month - 1,
						day = 1,
					})
					days_diff = days_diff
						+ os.date(
							"*t",
							os.time({
								year = os.date("*t", previous_month_time).year,
								month = os.date("*t", previous_month_time).month,
								day = 0,
							})
						).day
				end

				-- Handle negative months
				if months_diff < 0 then
					years_diff = years_diff - 1
					months_diff = months_diff + 12
				end

				-- Create the time difference string
				time_str = "*{:" .. task.filename .. ":" .. string.gsub(task.task, "^(%*+)%s*%b()%s*", "%1 ") .. "}["
				if years_diff > 0 then
					time_str = time_str .. years_diff .. "y"
				end
				if months_diff > 0 then
					time_str = time_str .. months_diff .. "m"
				end
				if days_diff > 0 then
					time_str = time_str .. days_diff .. "d"
				end
				time_str = time_str .. "]*"
			end
		else
			time_str = "*{:" .. task.filename .. ":" .. string.gsub(task.task, "%b()", "") .. "}[unscheduled]*"
		end

		local task_state_str = "\\[" .. task.state .. "\\] " .. (task.task):match("%)%s*(.+)")

		local priority_str = "  "
		if task.priority ~= "" and task.priority ~= nil then
			priority_str = priority_str .. "*" .. task.priority .. "*"
		else
			priority_str = priority_str .. " "
		end
		priority_str = priority_str .. "  "

		local line_str = "   " .. time_str
		line_str = line_str .. " ::" .. priority_str
		line_str = line_str .. ":: " .. task_state_str

		return line_str
	end,

	--- Adds the header and trailing line breaks to encapsulate the task lines
	--- @param buf_lines table
	--- @param header string
	--- @param tasks table
	--- @param curr_time integer
	insert_task_lines = function(buf_lines, header, tasks, curr_time)
		table.insert(buf_lines, "** " .. header)
		for _, task in ipairs(tasks) do
			table.insert(buf_lines, module.private.format_task_line(task, curr_time))
		end
		table.insert(buf_lines, "")
		table.insert(buf_lines, "")
	end,
}

module.public = {
	--- Generate agenda from Neorg files
	---@param input_list table
	page_view = function(input_list)
		local task_list = module.required["external.many-mans"]["task-man"].filter_tasks(input_list)

		-- Create and display agenda buffer
		local buffer_lines = {}
		local current_file = nil

		local year = tonumber(os.date("%Y"))
		local month = tonumber(os.date("%m"))
		local day = tonumber(os.date("%d"))

		local timetable = {
			year = year,
			month = month,
			day = day,
			hour = 0,
			min = 0,
			sec = 0,
		}

		-- Get the current weekday and adjust it to treat Monday as the start of the week
		local current_weekday = tonumber(os.date("%w", os.time(timetable)))
		current_weekday = (current_weekday == 0) and 7 or current_weekday -- Adjust Sunday (0) to be the last day of the week (7)

		table.insert(buffer_lines, "")
		table.insert(buffer_lines, "")
		table.insert(buffer_lines, "___")
		table.insert(buffer_lines, "* Today's Schedule")
		table.insert(
			buffer_lines,
			"  "
				.. os.date("%A", os.time(timetable))
				.. " == "
				.. year
				.. "-"
				.. month
				.. "-"
				.. day
				.. " == wk"
				.. os.date("%U", os.time(timetable))
		)
		table.insert(buffer_lines, "___")
		table.insert(buffer_lines, "")
		table.insert(buffer_lines, "")
		-- Format and insert tasks into the buffer
		for _, entry in ipairs(task_list) do
			if current_file ~= entry.filename then
				if current_file then
					table.insert(buffer_lines, "")
				end
				local file_metadata =
					module.required["external.many-mans"]["meta-man"].extract_file_metadata(entry.filename)
				-- table.insert(buffer_lines, "___")
				table.insert(buffer_lines, "")
				if file_metadata then
					table.insert(buffer_lines, "{:" .. entry.filename .. ":}[" .. file_metadata.title .. "]")
				else
					table.insert(buffer_lines, "{:" .. entry.filename .. ":}")
				end
				current_file = entry.filename
			end
			table.insert(buffer_lines, entry.task)
		end
		table.insert(buffer_lines, "")
		-- table.insert(buffer_lines, "___")

		-- Write formatted lines to the buffer
		local _, _ = module.required["external.many-mans"]["buff-man"].create_view_buffer(buffer_lines)
	end,

	--- Generate the Agenda Day View
	day_view = function()
		local year = tonumber(os.date("%Y"))
		local month = tonumber(os.date("%m"))
		local day = tonumber(os.date("%d"))

		local timetable = {
			year = year,
			month = month,
			day = day,
			hour = 0,
			min = 0,
			sec = 0,
		}

		-- Get the current weekday and adjust it to treat Monday as the start of the week
		local current_weekday = tonumber(os.date("%w", os.time(timetable)))
		current_weekday = (current_weekday == 0) and 7 or current_weekday -- Adjust Sunday (0) to be the last day of the week (7)

		-- Calculate the start of the week (Monday)
		local start_of_week_timestamp = os.time(timetable) - ((current_weekday - 1) * 24 * 60 * 60)
		local end_of_week_timestamp = start_of_week_timestamp + (6 * 24 * 60 * 60) -- End of the week (Sunday)

		-- Calculate the end of next week (Sunday of the next week)
		local end_of_next_week_timestamp = end_of_week_timestamp + (7 * 24 * 60 * 60)

		local current_time = os.time()

		local buffer_lines = {}
		table.insert(buffer_lines, "")
		table.insert(buffer_lines, "")
		table.insert(buffer_lines, "___")
		table.insert(buffer_lines, "* Today's Schedule")
		table.insert(
			buffer_lines,
			"  "
				.. os.date("%A", os.time(timetable))
				.. " == "
				.. year
				.. "-"
				.. month
				.. "-"
				.. day
				.. " == wk"
				.. os.date("%U", os.time(timetable))
		)
		table.insert(buffer_lines, "___")
		table.insert(buffer_lines, "")
		table.insert(buffer_lines, "")

		local task_list = module.required["external.many-mans"]["task-man"].filter_tasks({
			"undone",
			"pending",
			"hold",
			"important",
			"ambiguous",
		})

		local today = {}
		local overdue = {}
		local this_week = {}
		local next_week = {}
		local scheduled = {}
		local miscellaneous = {}

		-- Categorize and sort tasks
		for _, task in ipairs(task_list) do
			if
				task.deadline
				and tonumber(task.deadline.year)
				and tonumber(task.deadline.month)
				and tonumber(task.deadline.day)
			then
				local task_time = os.time({
					year = tonumber(task.deadline.year) or 2024,
					month = tonumber(task.deadline.month) or 8,
					day = tonumber(task.deadline.day) or 12,
					hour = 0,
					min = 0,
					sec = 0,
				})

				if task_time < current_time then
					if
						tonumber(task.deadline.day) == day
						and tonumber(task.deadline.month) == month
						and tonumber(task.deadline.year) == year
					then
						table.insert(today, task)
					else
						table.insert(overdue, task)
					end
				elseif task_time <= end_of_week_timestamp then
					table.insert(this_week, task)
				elseif task_time <= end_of_next_week_timestamp then
					table.insert(next_week, task)
				elseif task_time > end_of_next_week_timestamp then
					table.insert(scheduled, task)
				else
					table.insert(miscellaneous, task)
				end
			else
				table.insert(miscellaneous, task)
			end
		end

		-- Sort each category
		table.sort(today, module.private.sort_today_tasks)
		table.sort(overdue, module.private.sort_by_time_and_priority)
		table.sort(scheduled, module.private.sort_by_time_and_priority)
		table.sort(next_week, module.private.sort_by_time_and_priority)
		table.sort(this_week, module.private.sort_by_time_and_priority)

		module.private.insert_task_lines(buffer_lines, "Today", today, current_time)
		module.private.insert_task_lines(buffer_lines, "Overdue", overdue, current_time)
		module.private.insert_task_lines(buffer_lines, "This Week", this_week, current_time)
		module.private.insert_task_lines(buffer_lines, "Next Week", next_week, current_time)
		module.private.insert_task_lines(buffer_lines, "Scheduled", scheduled, current_time)

		table.insert(buffer_lines, "** Miscellaneous")
		for _, task in ipairs(miscellaneous) do
			local unscheduled_str = "*"
			unscheduled_str = unscheduled_str
				.. "{:"
				.. task.filename
				.. ":"
				.. string.gsub(task.task, "%b()", "")
				.. "}[unscheduled]*"

			local task_str = "\\[" .. task.state .. "\\] " .. (task.task):match("%)%s*(.+)")
			local tags_str = "`untagged`"
			local priority_str = "*unprioritised*"
			local line_str = "   " .. unscheduled_str
			line_str = line_str .. " :: " .. priority_str
			line_str = line_str .. " :: " .. task_str
			line_str = line_str .. " :: " .. tags_str
			table.insert(buffer_lines, line_str)
		end

		local _, _ = module.required["external.many-mans"]["buff-man"].create_view_buffer(buffer_lines)
	end,

	--- Generate Tag View
	tag_view = function()
		local year = tonumber(os.date("%Y"))
		local month = tonumber(os.date("%m"))
		local day = tonumber(os.date("%d"))

		local timetable = {
			year = year,
			month = month,
			day = day,
			hour = 0,
			min = 0,
			sec = 0,
		}

		-- Get the current weekday and adjust it to treat Monday as the start of the week
		local current_weekday = tonumber(os.date("%w", os.time(timetable)))
		current_weekday = (current_weekday == 0) and 7 or current_weekday -- Adjust Sunday (0) to be the last day of the week (7)

		local current_time = os.time()

		local buffer_lines = {}
		table.insert(buffer_lines, "")
		table.insert(buffer_lines, "")
		table.insert(buffer_lines, "___")
		table.insert(buffer_lines, "* Today's Schedule")
		table.insert(
			buffer_lines,
			"  "
				.. os.date("%A", os.time(timetable))
				.. " == "
				.. year
				.. "-"
				.. month
				.. "-"
				.. day
				.. " == wk"
				.. os.date("%U", os.time(timetable))
		)
		table.insert(buffer_lines, "___")
		table.insert(buffer_lines, "")
		table.insert(buffer_lines, "")

		local task_list = module.required["external.many-mans"]["task-man"].filter_tasks({
			"undone",
			"pending",
			"hold",
			"important",
			"ambiguous",
		})
		local tag_task_table = {}
		tag_task_table["untagged"] = {}
		for _, task in ipairs(task_list) do
			if task.tag then
				for _, tag in ipairs(task.tag) do
					if not tag_task_table[tag] then
						tag_task_table[tag] = {}
					end
					table.insert(tag_task_table[tag], task)
				end
			else
				table.insert(tag_task_table["untagged"], task)
			end
		end

		for key, tasks in pairs(tag_task_table) do
			module.private.insert_task_lines(buffer_lines, "`" .. key .. "`", tasks, current_time)
		end

		local _, _ = module.required["external.many-mans"]["buff-man"].create_view_buffer(buffer_lines)
	end,
}

module.on_event = function(event)
	-- vim.notify(vim.inspect(event))
	if event.split_type[2] == "external.agenda.page" then
		module.public.page_view(event.content)
	elseif event.split_type[2] == "external.agenda.day" then
		module.public.day_view()
	elseif event.split_type[2] == "external.agenda.tag" then
		module.public.tag_view()
	end
end

return module
