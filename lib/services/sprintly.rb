class Service::Sprintly < Service::Base
	title "Sprint.ly"

	string :dashboard_url, :placeholder => "https://sprint.ly/product/1/",
	       :label => 'URL for your Sprint.ly product dashboard'
	string :email, :placeholder => 'somebody@mycompany.com',
	       :label => "These values are encrypted to ensure your security. <br /><br />" \
                   'The email address you use to log in to Sprint.ly:'
	password :api_key, :placeholder => 'hg76thgjhgHGJHGjhghGvbfjnInjvex',
	         :label => 'Your Sprint.ly API key:'

	page "Product", [ :dashboard_url ]
	page "Login Information", [ :email, :api_key ]

	# Create a defect on Sprint.ly
	def receive_issue_impact_change(config, payload)
		url = items_api_url_from_dashboard_url(config[:dashboard_url])
		http.ssl[:verify] = true
		http.basic_auth config[:username], config[:password]

		users_text = ""
		crashes_text = ""
		if payload[:impacted_devices_count] == 1
			users_text = "This issue is affecting at least 1 user who has crashed "
		else
			users_text = "This issue is affecting at least #{ payload[:impacted_devices_count] } users who have crashed "
		end
		if payload[:crashes_count] == 1
			crashes_text = "at least 1 time.\n\n"
		else
			"at least #{ payload[:crashes_count] } times.\n\n"
		end

		issue_description = "Crashlytics detected a new issue.\n" + \
                 "#{ payload[:title] } in #{ payload[:method] }\n\n" + \
                 users_text + \
                 crashes_text + \
                 "More information: #{ payload[:url] }"

		post_body = { 'type' => 'defect',
									'title' => payload[:title] + ' [Crashlytics]',
									'description' => issue_description }

		resp = http_post url do |req|
			req.body = post_body
		end
		if resp.status != 200
			raise "[Sprint.ly] Adding defect to backlog failed: #{ resp[:status] }, body: #{ resp.body }"
		end
		{ :sprintly_item_number => JSON.parse(resp.body)['number'] }
	end

	def receive_verification(config, _)
		url = items_api_url_from_dashboard_url(config[:dashboard_url])
		http.ssl[:verify] = true
		http.basic_auth config[:email], config[:api_key]

		resp = http_get url
		if resp.status == 200
			[true,  "Successfully verified Sprint.ly settings"]
		else
			log "HTTP Error: status code: #{ resp.status }, body: #{ resp.body }"
			[false, "Oops! Please check your settings again."]
		end
	rescue => e
		log "Rescued a verification error in Sprint.ly: (url=#{config[:dashboard_url]}) #{e}"
		[false, "Oops! Is your product dashboard url correct?"]
	end

	private
	require 'uri'

	def items_api_url_from_dashboard_url(url)
		uri = URI(url)
		product_id = url.match(/(https?:\/\/.*?)\/product\/(\d*)(\/|$)/)[2]
		"https://sprint.ly/api/products/#{product_id}/items.json"
	end
end
