# Skadi

First-party, privacy-by-default analytics for Rails.

Skadi adds flexible and lightweight first-party analytics to your Rails app. Track page views and events, perform A/B testing and more, giving you all the information you need to improve your website.

Skadi is privacy-by-default, which means it respects users' privacy without any additional configuration. It gives you the power to be compliant with privacy laws*, while still collecting useful usage data about your site.

_* See [compliance section](#compliance)_

> [!NOTE]
> This is a human-written project with limited AI assistance. See the [AI Disclaimer](#ai-disclaimer) for details.

## Quick start

Install the gem:

```shell
bundle add skadi
```

Generate and run the database migration:

```shell
rails generate skadi:install
rails db:migrate
```

Add Skadi to your application controller:

```ruby
class ApplicationController
  include Skadi::Analytics
end
```

Add the Skadi tracking tag to your layout:

```erb
<%= skadi_tag %>
```

## AI Disclaimer

This gem is human-written, with AI used improve the quality of the code, corresponding to [level 3 to 4](https://www.visidata.org/blog/2026/ai/#self-assessed-ai-level-for-contributions) on the VisiData AI scale:

> **Level 3**: Human coded, bots assisted non-trivially  
> **Level 4**: Human coded, bots helped significantly

AI was used for same-line autocomplete suggestions, research and code review. Humans made all the architectural decisions, logic and the resulting code.

## Why use Skadi?

> **Todo:**  
> add why skadi is great


## Compliance

Skadi respects users' privacy without any additional configuration. This means that Skadi will not store any personal data or track indiviidual users without explicit consent.

> [!NOTE]
> It is your responsibility to comply with any applicable privacy laws. Skadi does not provide any legal advice as to the compliance of your use of Skadi.

### Cookies

The __skadi_id__ cookie is used to store a unique identifier for a user. This identifier is used to track the user across multiple visits to the site. This cookie is set when the `window.skadi.consent()` function is called in the front end.

The __skadi_tracking_opt_out__ cookie is used to indicate the user has opted out of tracking. This is a necessary cookie and does not contain any user information. This cookie is set when the `window.skadi.optOut()` function is called in the front end.

### Anonymity Sets

Some DPAs provide exceptions that allow for limited tracking of users before they consent, provided that the data is aggregated within a short time-frame. For example, the [Statistical Purposes exception](https://ico.org.uk/for-organisations/direct-marketing-and-privacy-and-electronic-communications/guidance-on-the-use-of-storage-and-access-technologies/what-are-the-exceptions/#statistical) for the UK GDPR.

Skadi allows you to enable the use of pseudonymous "anonymity sets" that can track a user's visit across multiple pages throughout a day:

```ruby
Skadi.configure do |config|
  config.use_anonymity_sets = true
end
```

This anonymity set is calculated using a hash of the User's IP Address, their User Agent, and a random value called a pepper.

```
anonymity_set = hash(ip_address + user_agent + pepper)
```

Although the resulting value contains no personal information, it can still be used to track users, so it is considered pseudonymous rather than truly anonymous, and thus still subject to privacy laws. Once the pepper has been discarded, the anonymity set can no longer track users; the pepper is rotated and discarded daily, making the data collected fully anonymous.

Many privacy laws also require that users be given the option to opt-out of anonymisation-set tracking. Calling the `window.skadi.optOut()` function in the front end will set a cookie that will prevent Skadi from generating anonymisation sets for that user. Their views and events will still be collected, but no personal data will be stored.

## Configuration

> **Todo:**  
> add configuration details


