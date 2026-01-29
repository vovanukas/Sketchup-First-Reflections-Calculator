require 'sketchup.rb'
require 'extensions.rb'

#-------------------------------------------------------------------------------

module VM
  module FirstReflectionsCalculator

      ### CONSTANTS ### ------------------------------------------------------------

      # Plugin information
      PLUGIN_ID       = 'VM_FirstReflectionsCalculator'.freeze
      PLUGIN_NAME     = 'First Reflections Calculator'.freeze
      PLUGIN_VERSION  = '1.1.0'.freeze

      # Resource paths
      FILENAMESPACE = File.basename( __FILE__, '.rb' )
      PATH_ROOT     = File.dirname( __FILE__ ).freeze
      PATH          = File.join( PATH_ROOT, FILENAMESPACE ).freeze


      ### EXTENSION ### ------------------------------------------------------------

      unless file_loaded?( __FILE__ )
        loader = File.join( PATH, 'main.rb' )
        ex = SketchupExtension.new( PLUGIN_NAME, loader )
        ex.description = 'Calculate First Reflections Using Raytracing.'
        ex.version     = PLUGIN_VERSION
        ex.copyright   = 'Vladimiras Malyskinas 2026'
        ex.creator     = 'Vladimiras Malyskinas'
        Sketchup.register_extension( ex, true )
      end

  end # module FirstReflectionsCalculator
end # module VM

#-------------------------------------------------------------------------------

file_loaded( __FILE__ )

#-------------------------------------------------------------------------------