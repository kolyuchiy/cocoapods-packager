module Pod
  class Command
    class Package < Command
      :private

      def install_pod(platform_name, source_dir)
        podfile = podfile_from_spec(
          File.basename(@path),
          @spec.name,
          platform_name,
          @spec.deployment_target(platform_name),
          @subspecs,
          @spec_sources,
          source_dir
        )

        sandbox = Sandbox.new(config.sandbox_root)
        installer = Installer.new(sandbox, podfile)
        installer.install!

        unless installer.nil?
          installer.pods_project.targets.each do |target|
            target.build_configurations.each do |config|
              config.build_settings['CLANG_MODULES_AUTOLINK'] = 'NO'
              config.build_settings['CLANG_ENABLE_MODULES'] = 'NO'
              config.build_settings['GCC_PRECOMPILE_PREFIX_HEADER'] = 'NO'
            end
          end
          installer.pods_project.save
        end

        sandbox
      end

      def podfile_from_spec(path, spec_name, platform_name, deployment_target, subspecs, sources, source_dir)
        Pod::Podfile.new do
          sources.each { |s| source s }
          platform(platform_name, deployment_target)
          if path
            if subspecs
              subspecs.each do |subspec|
                pod spec_name + '/' + subspec, :path => source_dir
              end
            else
              pod spec_name, :path => source_dir
            end
          else
            if subspecs
              subspecs.each do |subspec|
                pod spec_name + '/' + subspec, :path => '.'
              end
            else
              pod spec_name, :path => '.'
            end
          end
        end
      end

      def binary_only?(spec)
        deps = spec.dependencies.map { |dep| spec_with_name(dep.name) }

        [spec, *deps].each do |specification|
          %w(vendored_frameworks vendored_libraries).each do |attrib|
            if specification.attributes_hash[attrib]
              return true
            end
          end
        end

        false
      end

      def spec_with_name(name)
        return if name.nil?

        set = SourcesManager.search(Dependency.new(name))
        return nil if set.nil?

        set.specification.root
      end

      def spec_with_path(path)
        return if path.nil? || !Pathname.new(path).exist?

        @path = path

        if Pathname.new(path).directory?
          help! path + ': is a directory.'
          return
        end

        unless ['.podspec', '.json'].include? Pathname.new(path).extname
          help! path + ': is not a podspec.'
          return
        end

        Specification.from_file(path)
      end
    end
  end
end
