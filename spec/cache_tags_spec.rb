# coding: utf-8

require 'spec_helper'
require 'fileutils'
require 'active_support/core_ext'

describe Rails::Cache::Tags do
  shared_examples 'cache with tags support for' do |object|
    before { cache.clear }

    def assert_read(key, object)
      expect(cache.exist?(key)).to eq !!object
      expect(cache.read(key)).to eq object
    end

    def assert_blank(key)
      assert_read key, nil
    end

    it 'reads and writes a key with tags' do
      cache.write 'foo', object, :tags => 'baz'

      assert_read 'foo', object
    end

    it 'deletes a key if tag is deleted' do
      cache.write('foo', object, :tags => 'baz')
      cache.delete_tag 'baz'

      assert_blank 'foo'
    end

    it 'reads a key if another tag was deleted' do
      cache.write('foo', object, :tags => 'baz')
      cache.delete_tag 'fu'

      assert_read 'foo', object
    end

    it 'reads and writes if multiple tags given' do
      cache.write('foo', object, :tags => [:baz, :kung])

      assert_read 'foo', object
    end

    it 'deletes a key if one of tags is deleted' do
      cache.write('foo', object, :tags => [:baz, :kung])
      cache.delete_tag :kung

      assert_blank 'foo'
    end

    #it 'does not read a key if it is expired' do
    #  ttl = 0.01
    #  # dalli does not support float TTLs
    #  ttl *= 100 if cache.class.name == 'ActiveSupport::Cache::DalliStore'
    #
    #  cache.write 'foo', object, :tags => [:baz, :kung], :expires_in => ttl
    #
    #  sleep ttl * 2
    #
    #  assert_blank 'foo'
    #end

    it 'reads and writes a key if hash of tags given' do
      cache.write('foo', object, :tags => {:baz => 1})
      assert_read 'foo', object

      cache.delete_tag :baz => 2
      assert_read 'foo', object

      cache.delete_tag :baz => 1
      assert_blank 'foo'
    end

    it 'reads and writes a key if array of object given as tags' do
      tag1 = 1.day.ago
      tag2 = 2.days.ago

      cache.write 'foo', object, :tags => [tag1, tag2]
      assert_read 'foo', object

      cache.delete_tag tag1
      assert_blank 'foo'
    end

    it 'reads multiple keys with tags check' do
      cache.write 'foo', object, :tags => :bar
      cache.write 'bar', object, :tags => :baz

      assert_read 'foo', object
      assert_read 'bar', object

      cache.delete_tag :bar

      assert_blank 'foo'
      assert_read 'bar', object

      expect(cache.read_multi('foo', 'bar')).to eq('foo' => nil, 'bar' => object)
    end

    it 'fetches key with tag check' do
      cache.write 'foo', object, :tags => :bar

      expect(cache.fetch('foo') { 'baz' }).to eq object
      expect(cache.fetch('foo')).to eq object

      cache.delete_tag :bar

      expect(cache.fetch('foo')).to be_nil
      expect(cache.fetch('foo', :tags => :bar) { object }).to eq object
      assert_read 'foo', object

      cache.delete_tag :bar

      assert_blank 'foo'
    end
  end

  class ComplexObject < Struct.new(:value)
  end

  SCALAR_OBJECT = 'bar'
  COMPLEX_OBJECT = ComplexObject.new('bar')

  shared_examples 'cache with tags support' do |*tags|
    context '', tags do
      include_examples 'cache with tags support for', SCALAR_OBJECT
      include_examples 'cache with tags support for', COMPLEX_OBJECT

      # test everything with locale cache
      include_examples 'cache with tags support for', SCALAR_OBJECT do
        include ActiveSupport::Cache::Strategy::LocalCache

        around(:each) do |example|
          if cache.respond_to?(:with_local_cache)
            cache.with_local_cache { example.run }
          end
        end
      end

      include_examples 'cache with tags support for', COMPLEX_OBJECT do
        include ActiveSupport::Cache::Strategy::LocalCache

        around(:each) do |example|
          cache.with_local_cache { example.run }
        end
      end
    end
  end

  it_should_behave_like 'cache with tags support', :memory_store do
    let(:cache) { ActiveSupport::Cache.lookup_store(:memory_store, :expires_in => 60, :size => 100) }
  end

  it_should_behave_like 'cache with tags support', :file_store do
    let(:cache_dir) { File.join(Dir.pwd, 'tmp_cache') }
    before { FileUtils.mkdir_p(cache_dir) }
    after  { FileUtils.rm_rf(cache_dir) }

    let(:cache) { ActiveSupport::Cache.lookup_store(:file_store, cache_dir, :expires_in => 60) }
  end

  it_should_behave_like 'cache with tags support', :memcache, :mem_cache_store do
    let(:cache) { ActiveSupport::Cache.lookup_store(:mem_cache_store, :expires_in => 60) }
  end

  it_should_behave_like 'cache with tags support', :memcache, :dalli_store do
    let(:cache) { ActiveSupport::Cache.lookup_store(:dalli_store, :expires_in => 60) }
  end
end