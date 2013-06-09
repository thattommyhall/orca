Hull.extension :file_sync do
  class Hull::Package
    def file(config)
      Hull::FileSync.new(self, config).configure
    end
  end
end

class Hull::FileSync
  def initialize(parent, config)
    @parent = parent
    @config = config
    raise ArgumentError.new('A file :source must be provided') unless local_path
    raise ArgumentError.new('A file :destination must be provided') unless remote_path
  end

  def local_path
    @config[:source]
  end

  def remote_path
    @config[:destination]
  end

  def permissions
    @config[:permissions]
  end

  def user
    @config[:user]
  end

  def group
    @config[:group]
  end

  def create_dir
    @config[:create_dir] || @config[:create_dirs]
  end

  def package_name(suffix)
    "file-#{suffix}[#{remote_path}]"
  end

  def configure
    fs = self
    add_content_package
    add_permissions_package unless permissions.nil? and user.nil? and group.nil?
  end

  def add_content_package
    fs = self
    add_package('content') do |package|
      package.command :apply do
        if fs.create_dir
          mk_dir = fs.create_dir == true ? File.dirname(fs.remote_path) : fs.create_dir
          run("mkdir -p #{mk_dir}")
        end
        local(fs.local_path).copy_to(remote(fs.remote_path))
      end

      package.command :remove do
        remote(fs.remote_path).delete!
      end

      package.command :validate do
        local(fs.local_path).matches?(remote(fs.remote_path))
      end
    end
  end

  def add_permissions_package
    fs = self
    add_package('permissions') do |package|
      package.command :apply do
        remote(fs.remote_path).set_owner(fs.user, fs.group) unless fs.user.nil? and fs.group.nil?
        remote(fs.remote_path).set_permissions(fs.permissions) unless fs.permissions.nil?
      end

      package.command :validate do
        r_file = remote(fs.remote_path)
        valid = r_file.permissions == fs.permissions
        valid = valid && r_file.user == fs.user if fs.user
        valid = valid && r_file.group == fs.group if fs.group
        valid
      end
    end
  end

  def add_package(suffix)
    package = Hull.add_package(package_name(suffix))
    yield(package)
    @parent.triggers(package.name)
    package
  end
end