module ActiveRecord
  module AttrReadable
  
    def self.included(base)
      base.extend(ClassMethods)
    end
  
    def sanitized_hash(role = :default)
      self.class.sanitized_hash_from_model(self, role)
    end
  
    # Use the attr_readable expresion to define and control read access to 
    # individual attributes of an +ActiveRecord+.
    #
    # The attr_readable plugin's design goal is to provide a mechanism
    # for role-based authorizing access to indiviual attributes of the 
    # resource, where the mechanism closely resembles the interface of the 
    # mass-assignment access control in +ActiveRecord+.
    module ClassMethods
        
      # Specifies a white list of model attributes that can be accessed by a 
      # specific role for reading.
      #
      # A role for the attributes is optional. If no role is provided, then 
      # :default is used. A role can be defined by using the :as option, 
      # arbitrary symbols are acceptable. It's possible to set attribute 
      # accessibility for several roles at once by passing several role-symbols 
      # in an array, like in:
      #  attr_readable :id, :type, :name, :as => [ :default, :user, :admin ]
      def attr_readable(*args)
        options = args.extract_options!
        role = options[:as]   || :default
        
        attributes_to_add = args.map { |attr| attr.to_s }  # make strings from symbols
    
        @_readable_attributes = readable_attributes_configs.dup  # why duplicate and re-assign? because someone else may hold the original array (e.g. in case part of it is used in this very call to attr_access)
    
        Array.wrap(role).each do | r |
          @_readable_attributes[r] = readable_attributes(r) | attributes_to_add  # add to the set
        end
      end
  
      def readable_attributes(role = :default)
        readable_attributes_configs[role]            # map arguments to an access to a hash of roles
      end
    
      def sanitized_hash_from_model(object, role = :default)
        sanitized_hash_from_keys_and_whitelist(object.attribute_names, object, readable_attributes(role))
      end
    
      def sanitized_hash_from_hash(hash, role = :default)
        sanitized_hash_from_keys_and_whitelist(hash.keys, hash, readable_attributes(role))
      end
  
      private
  
        def sanitized_hash_from_keys_and_whitelist(keys, hash, whitelist)
          result = {}
          keys.each { |attr| result[attr.to_sym] = hash[attr] if whitelist.include? attr.to_s }
          return result
        end
  
        # Private method managing the access to the attributes hash of hashes. 
        # Automatically constructs a new hash, if there hasn't been any.
        def readable_attributes_configs
          @_readable_attributes ||= begin     # return the hash of hashes or create it
            Hash.new do |h,k|                        # create the outer-hash (:role)
              h[k] =  []                             #   with a default value that is an empty array (will hold the attributes)
            end
          end
        end
    end
  
  end
end

