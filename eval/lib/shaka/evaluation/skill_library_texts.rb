# frozen_string_literal: true

require 'date'
require 'json'
require 'yaml'
require_relative '../../../../skills/shaka/lib/shaka/error'

module Shaka
  module Evaluation
    # Builds the text a skill library adds to an agent session, read from a checkout without running it:
    # what every session loads once the library is installed, and what using one skill loads.
    module SkillLibraryTexts
      Skill = Data.define(:name, :description, :body)

      # What a default install of each library registers, relative to its checkout. `skills` is a list of
      # globs, a plugin manifest's skill list, or every plugin in a marketplace manifest.
      LIBRARIES = {
        'shaka' => { 'skills' => ['skills/shaka/SKILL.md'], 'per_use' => 'shaka_workflow' },
        'mattpocock/skills' => { 'skills' => { 'plugin' => '.claude-plugin/plugin.json' } },
        'obra/superpowers' => { 'skills' => ['skills/*/SKILL.md'], 'session' => 'superpowers' },
        'anthropics/skills' => { 'skills' => { 'marketplace' => '.claude-plugin/marketplace.json' } },
        'garrytan/gstack' => { 'skills' => ['SKILL.md', '*/SKILL.md'] },
        'addyosmani/agent-skills' => { 'skills' => ['skills/*/SKILL.md'],
                                       'commands' => ['commands/*.md', '.claude/commands/*.md'] }
      }.freeze

      # Superpowers' hooks/session-start wraps its using-superpowers skill in this shell assignment.
      SUPERPOWERS_HOOK = /^session_context="(.*\$\{using_superpowers_escaped\}.*)"$/
      SUPERPOWERS_SKILL = 'skills/using-superpowers/SKILL.md'

      module_function

      # `shaka_workflow` is the rendered workflow that invoking Shaka loads after its SKILL.md.
      def library(name, root, shaka_workflow: nil)
        rule = LIBRARIES.fetch(name)
        skills = skills(name, root, rule)
        commands = globbed(root, rule['commands']).map { |path| command(root, path) }
        { 'skills' => skills.size, 'commands' => commands.size,
          'every_session' => every_session(root, skills + commands, rule['session']),
          **per_use_texts(skills, rule['per_use'] && shaka_workflow) }
      end

      def skills(name, root, rule)
        skills = skill_paths(root, rule.fetch('skills')).map { |path| skill(root, path) }
        raise Shaka::Error, "#{name}: no skills found in #{root}" if skills.empty?

        skills
      end

      def skill_paths(root, rule)
        return globbed(root, rule) if rule.is_a?(Array)

        manifest_dirs(root, rule).map { |dir| File.join(dir.delete_prefix('./'), 'SKILL.md') }.uniq
      end

      def manifest_dirs(root, rule)
        return manifest(root, rule['plugin']).fetch('skills') if rule.key?('plugin')

        manifest(root, rule['marketplace']).fetch('plugins').flat_map { |plugin| Array(plugin['skills']) }
      end

      def globbed(root, globs) = Array(globs).flat_map { |glob| Dir.glob(glob, base: root).sort }

      def manifest(root, path) = JSON.parse(checkout_text(root, path))

      # Every file must resolve inside the library's checkout. A manifest entry or symlink that leads
      # elsewhere would send unrelated local text to the CLIs, so it stops the reader.
      def checkout_text(root, path)
        full = File.realpath(File.join(root, path))
        return File.read(full, encoding: 'UTF-8') if full.start_with?("#{File.realpath(root)}/")

        raise Shaka::Error, "#{path} resolves outside the checkout"
      end

      def skill(root, path)
        meta, body = frontmatter(checkout_text(root, path), path)
        Skill.new(name: (meta['name'] || File.basename(File.dirname(path))).to_s,
                  description: meta['description'].to_s.split.join(' '), body:)
      end

      def command(root, path)
        meta, = frontmatter(checkout_text(root, path), path)
        Skill.new(name: File.basename(path, '.md'), description: meta['description'].to_s.split.join(' '), body: '')
      end

      def frontmatter(text, path)
        match = text.match(/\A---\s*\n(.*?)\n---\s*(?:\n|\z)/m)
        return [{}, text] unless match

        meta = YAML.safe_load(match[1], permitted_classes: [Date, Time]) || {}
        [meta.is_a?(Hash) ? meta : {}, match.post_match]
      rescue Psych::Exception => e
        raise Shaka::Error, "#{path}: unreadable frontmatter (#{e.class})"
      end

      # Every entry is listed as "- name: description", the same for each library.
      def every_session(root, entries, session)
        listing = entries.map { |entry| "- #{entry.name}: #{entry.description}" }.join("\n")
        session == 'superpowers' ? "#{listing}\n\n#{superpowers_session(root)}" : listing
      end

      # Rebuilds the hook's text from the hook itself, so a rerun on a changed hook fails instead of
      # counting stale text. The script's \n escapes become newlines once its JSON output is decoded;
      # any other escape is a shape this reader does not model.
      def superpowers_session(root)
        hook = 'hooks/session-start'
        wrapper = File.exist?(File.join(root, hook)) && checkout_text(root, hook)[SUPERPOWERS_HOOK, 1]
        unless wrapper && !wrapper.match?(/\\[^n]/)
          raise Shaka::Error, 'obra/superpowers: hooks/session-start no longer sets session_context as read'
        end

        content = checkout_text(root, SUPERPOWERS_SKILL).sub(/\n+\z/, '')
        wrapper.gsub('\n', "\n").sub('${using_superpowers_escaped}') { content }
      end

      # The median and the largest skill body by words. Shaka's one skill loads its workflow too.
      def per_use_texts(skills, workflow)
        if workflow
          shaka = shaka_use(skills, workflow)
          return { 'median_skill' => shaka, 'largest_skill' => shaka }
        end

        sorted = skills.sort_by { |skill| [skill.body.split.size, skill.name] }
        { 'median_skill' => use(sorted[sorted.size / 2]), 'largest_skill' => use(sorted.last) }
      end

      def use(skill) = { 'name' => skill.name, 'text' => skill.body }

      def shaka_use(skills, workflow) = { 'name' => skills.first.name, 'text' => "#{skills.first.body}\n\n#{workflow}" }
    end
  end
end
