module ActiveRecord
  
  # Use the attr_readable plugin to define and control read access to 
  # individual attributes of an +ActiveRecord+.
  #
  # The exepression +attr_readable+ can be used inside the class defintion
  # of an +ActiveRecord+ to provide a list of readable attributes. The list
  # can be appended with a specification of the role that should  be granted 
  # read access:
  #
  #  attr_readable :attribute_1, :attribute_2, :as => :user 
  #
  # Arbitrary symbols area accetable as roles. If no role is provided, then 
  # :default is used. 
  #
  #  attr_readable :attribute   # same as using :as => :default
  #
  # It's possible to set attribute accessibility for several roles at once 
  # by passing several role-symbols in an array.
  #
  #  class Model < ActiveRecord::Base
  #    attr_readable :id, :name, :as => [ :default, :user, :admin ]
  #  end
  #
  # would have the same result as
  #
  #  class Model < ActiveRecord::Base
  #    attr_readable :id, :name, :as => :default
  #    attr_readable :id, :name, :as => :user
  #    attr_readable :id, :name, :as => :admin 
  #  end
  #
  # In both the above examples only the attributes :id and :name are
  # marked as readable for the three specified roles. Please note, an unkown
  # role has access to no attributes by default.
  #
  # You can access the list of attributes readable by a apecific role using
  # the accessor method <tt>readable_attributes(role)</tt>. 
  #
  #  Model.readable_attributes(:admin)        # => [ :id, :name ]
  #  Model.readable_attributes(:other_role)   # => [ ]
  #
  # Besides this mechanism to manage a list of readable attributes for several
  # roles, the module provides several methods for sanitizing instances of the
  # ActiveRecord according to the specified rules. Most important is the 
  # instance method #sanitized_hash(role) that returns a hash of only the 
  # readable attributes and their values for a given role.
  #
  # Examples:
  #
  #  instance = Model.create( :name => 'a_name', :other_attribute => 'a_value' )
  #  instance.sanitized_hash(:admin)        # => { :id => 1, :name => 'a_name' }
  #  instance.sanitized_hash(:other_role)   # => { }
  #
  # The module also provides two more class methods for sanitation:
  # * <tt>sanitized_hash_from_model</tt> - Returns a sanitized hash for the 
  #   specified instance of the model.
  # * <tt>sanitized_hash_from_hash</tt> - Returns a sanitzized hash created from 
  #   the specified hash according to the readable attributes of the model.
  #
  module AttrReadable 
  
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
    end
  
    # Returns an hash that contains only the attributes and values that
    # the specified role is allowed to read
    #
    #   model.sanitized_hash(:user)  #  => { :readable_attribute1 => 'value', :readable_attribute2 => 'value2' }
    def sanitized_hash(role = :default)
      self.class.sanitized_hash_from_model(self, role)
    end
  
    # Use the +attr_readable+ expresion to define and control read access to 
    # individual attributes of an +ActiveRecord+. Use the additional class
    # methods to query readable attributes and to receive sanitzed hashes
    # that only contain values of readable attributes.
    module ClassMethods
        
      # Use to specify a white list of model attributes that can be accessed by a 
      # specific role for reading.
      #
      #  class Model < ActiveRecord::Base
      #    attr_readable :id, :name, :as => [ :default, :user, :admin ]
      #    attr_readable :name,      :as => [ :non_privileged ]
      #  end
      #
      def attr_readable(*args)
        options = args.extract_options!
        role = options[:as]   || :default
        
        attributes_to_add = args.map { |attr| attr.to_s }  # make strings from symbols
    
        @_readable_attributes = readable_attributes_configs.dup  # why duplicate and re-assign? because someone else may hold the original array (e.g. in case part of it is used in this very call to attr_access)
    
        Array.wrap(role).each do | r |
          @_readable_attributes[r] = readable_attributes(r) | attributes_to_add  # add to the set
        end
      end
  
      # Returns the list of attributes that are readable by the specified role.
      #
      #   Model.readable_attributes(:admin)    # => [ :id, :name ]
      def readable_attributes(role = :default)
        readable_attributes_configs[role]            # map arguments to an access to a hash of roles
      end
    
      # Returns a hash that only contains attribute - value pairs of only the
      # attributes set readable to the given role.
      #
      #  Model.sanitized_hash_from_model(instace_of_model, :admin)  # => [ :id => a_number, :name => 'a name' ]
      def sanitized_hash_from_model(object, role = :default)
        sanitized_hash_from_keys_and_whitelist(object.attribute_names, object, readable_attributes(role))
      end

      # Returns a hash that only contains those attribute - value pairs of 
      # the original hash that match attributes set readable to the given role.
      #
      #  Model.sanitized_hash_from_hash({ :attribute => 'value', :name => 'a name }, :admin)  # => [ :name => 'a name' ]    
      def sanitized_hash_from_hash(hash, role = :default)
        sanitized_hash_from_keys_and_whitelist(hash.keys, hash, readable_attributes(role))
      end
  
      private
      
        # Private method that actually does the sanitization. Is called by all the 
        # other sanitization methods.  
        def sanitized_hash_from_keys_and_whitelist(keys, hash, whitelist) # :nodoc:
          prefixes   = []
          attributes = []
          whitelist.each do |attr|            # split whitelist into fully qulified attributes and prefixes
            if attr.end_with? '_' 
              prefixes.push attr
            else 
              attributes.push attr
            end
          end

          result = {}
          keys.each do |attr| 
            if attributes.include? attr.to_s  # corresponding attribute
              result[attr.to_sym] = hash[attr]
            else
              prefixes.each do |prefix|
                result[attr.to_sym] = hash[attr]  if attr.to_s.start_with? prefix
              end
            end 
          end
          return result
        end
  
        # Private method managing the access to the attributes hash of hashes. 
        # Automatically constructs a new hash, if there hasn't been any.
        def readable_attributes_configs       # :nodoc:
          @_readable_attributes ||= begin     # return the hash of hashes or create it
            Hash.new do |h,k|                 # create the outer-hash (:role)
              h[k] =  []                      #   with a default value that is an empty array (will hold the attributes)
            end
          end
        end
    end
  
  end
end

