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

## AI Disclaimer

This gem is human-written, with AI used improve the quality of the code, corresponding to [level 3 to 4](https://www.visidata.org/blog/2026/ai/#self-assessed-ai-level-for-contributions) on the VisiData AI scale:

> **Level 3**: Human coded, bots assisted non-trivially  
> **Level 4**: Human coded, bots helped significantly

AI was used for same-line autocomplete suggestions, research and code review. Humans made all the architectural decisions, logic and the resulting code.

## Why use Skadi?

> **Todo:**  
> add why skadi is great


## Compliance

> **Todo:**  
> add compliance details


## Configuration

> **Todo:**  
> add configuration details


