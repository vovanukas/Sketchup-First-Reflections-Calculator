require 'sketchup.rb'
require 'json'
require 'time'

module VM
  module FirstReflectionsCalculator

    def self.get_user_id
      @user_id ||= begin
        id = Sketchup.read_default("VM_FirstReflectionsCalculator", "UserID")
        if id.nil?
          # Generate a simple unique ID (random hex)
          id = Array.new(16) { rand(256) }.pack('C*').unpack('H*').first
          Sketchup.write_default("VM_FirstReflectionsCalculator", "UserID", id)
        end
        id
      end
    end

    def self.capture_event(event, properties = {})
      user_id = self.get_user_id
            
      # Obfuscated API Key
      encoded_key = "cGhjX0xoUUZyZzhvYVFNTlRkcEdKUGljNFg1bFFRdnIyNjg5WlNUSkd2UnpFY2k="
      api_key = encoded_key.unpack1('m')
      
      # Use Sketchup's built-in HTTP request
      url = "https://eu.i.posthog.com/capture/"
      request = Sketchup::Http::Request.new(url, Sketchup::Http::POST)
      
      data = {
        api_key: api_key,
        event: event,
        properties: properties.merge({
          distinct_id: user_id,
          plugin_version: PLUGIN_VERSION,
          sketchup_version: Sketchup.version,
          "$process_person_profile": false # Disabled personal profile collection
        }),
        timestamp: Time.now.iso8601
      }
      
      request.headers = { "Content-Type" => "application/json" }
      request.body = data.to_json
      
      request.start do |req, res|
        # puts "PostHog event sent: #{event} (Status: #{res.status_code})"
      end
    rescue => e
      puts "PostHog capture error: #{e.message}"
    end

    class FirstReflectionsTool
      ARROW_LENGTH = 16  # Length of the direction arrow in inches
      ARROW_HEAD_LENGTH = 5  # Length of the cone arrowhead
      ARROW_HEAD_RADIUS = 2.5  # Radius of the cone base
      CONE_SEGMENTS = 12  # Number of segments for the cone (smoother = more)
      
      # Set-up instance variables when the tool is activated
      def activate
        @mouse_ip = Sketchup::InputPoint.new # Input Point is used to pick 3d point, which reside under the cursor
        @face = nil
        @model = Sketchup.active_model # Get active model
        @entities = @model.entities # Get entities class; Needed to spawn CLines
        @reflections_folder = @model.layers.folders.find {|f| f.name == "Reflections | VMFRC" }
        @dialog = nil
        
        # For cursor visualization
        @hover_position = nil
        @hover_normal = nil
        
        Sketchup.status_text = "Click on a face to calculate reflections"
      end
      
      def deactivate(view)
        view.invalidate  # Clean up any drawing
      end
      
      # Track mouse movement to show direction arrow
      def onMouseMove(flags, x, y, view)
        @mouse_ip.pick(view, x, y)
        
        face = @mouse_ip.face
        if face
          @hover_position = @mouse_ip.position
          # Transform normal to global coordinates (handles faces inside groups/components)
          @hover_normal = face.normal.transform(@mouse_ip.transformation)
        else
          @hover_position = nil
          @hover_normal = nil
        end
        
        view.invalidate  # Request a redraw
      end
      
      # Draw the direction arrow overlay
      def draw(view)
        return unless @hover_position && @hover_normal
        
        # The cone starts where the shaft ends
        cone_base_point = @hover_position.offset(@hover_normal, ARROW_LENGTH - ARROW_HEAD_LENGTH)
        cone_tip = @hover_position.offset(@hover_normal, ARROW_LENGTH)
        
        # Draw the main arrow shaft (line from origin to cone base)
        view.line_stipple = ''  # Solid line
        view.line_width = 2
        view.drawing_color = Sketchup::Color.new(220, 60, 60)  # Slightly softer red
        view.draw_line(@hover_position, cone_base_point)
        
        # Draw the cone arrowhead
        draw_cone(view, cone_base_point, cone_tip, @hover_normal)
      end
      
      # Draw a filled cone arrowhead
      def draw_cone(view, base_center, tip, direction)
        # Create perpendicular vectors for the cone base circle
        if direction.parallel?(Z_AXIS)
          perp1 = X_AXIS.clone
        else
          perp1 = direction.cross(Z_AXIS)
        end
        perp1.normalize!
        perp2 = direction.cross(perp1)
        perp2.normalize!
        
        # Generate points around the base circle
        base_points = []
        CONE_SEGMENTS.times do |i|
          angle = (2 * Math::PI * i) / CONE_SEGMENTS
          offset1 = Geom::Vector3d.new(
            perp1.x * Math.cos(angle) + perp2.x * Math.sin(angle),
            perp1.y * Math.cos(angle) + perp2.y * Math.sin(angle),
            perp1.z * Math.cos(angle) + perp2.z * Math.sin(angle)
          )
          base_points << base_center.offset(offset1, ARROW_HEAD_RADIUS)
        end
        
        # Draw the cone surface as triangles (tip to each edge segment)
        view.drawing_color = Sketchup::Color.new(255, 80, 80)  # Bright red for cone
        
        CONE_SEGMENTS.times do |i|
          next_i = (i + 1) % CONE_SEGMENTS
          triangle = [tip, base_points[i], base_points[next_i]]
          view.draw(GL_TRIANGLES, triangle)
        end
        
        # Draw the base cap
        view.drawing_color = Sketchup::Color.new(180, 50, 50)  # Darker red for base
        view.draw(GL_POLYGON, base_points)
      end

      # Method when user presses the Left Mouse Button
      def onLButtonDown(flag, x, y, view)
        @mouse_ip.pick(view, x, y) # Pick the 3D point below the cursor

        @face = @mouse_ip.face # Get face that the cursor has been clicked on
        if @face.nil?
          UI.messagebox("Point must be on a face.")
          return
        end

        @clicked_position = @mouse_ip.position
        # Store the face normal in global coordinates (handles faces inside groups/components)
        @clicked_face_normal = @face.normal.transform(@mouse_ip.transformation)
        show_dialog
      end

      def show_dialog
        if @dialog && @dialog.visible?
          @dialog.bring_to_front
          return
        end

        @dialog = UI::HtmlDialog.new({
          :dialog_title => "First Reflections Calculator",
          :preferences_key => "com.vm.firstreflections",
          :scrollable => false,
          :resizable => true, # Allow resizing for auto-fit
          :width => 300,
          :height => 350,
          :style => UI::HtmlDialog::STYLE_DIALOG
        })

        html_path = File.join(PATH, 'dialog.html')
        @dialog.set_file(html_path)

        @dialog.add_action_callback("resize") do |action_context, width, height|
          # Use set_size to match content height, adding a small buffer
          @dialog.set_size(width, height + 40)
        end

        @dialog.add_action_callback("callback") do |action_context, type, data|
          case type
          when "ok"
            n_of_rays = data["rays"].to_i
            n_of_reflections = data["reflections"].to_i
            
            @dialog.close
            calculate_first_reflections(@clicked_position, n_of_rays, n_of_reflections)
          when "cancel"
            @dialog.close
          when "learnmore"
            VM::FirstReflectionsCalculator.capture_event('learn_more_clicked')
            UI.openURL("https://tally.so/r/WOrx8J")
          end
        end

        @dialog.show
      end

      def calculate_first_reflections(position, n_of_rays, n_of_reflections, reflection_vector=nil)
        if n_of_reflections > 0
          if reflection_vector.nil?
            # Track calculation start
            VM::FirstReflectionsCalculator.capture_event('calculation_started', {
              rays: n_of_rays,
              reflections: n_of_reflections
            })

            @model.start_operation('Calculate Reflections', true)

            # Ensure folder exists (handles deleted/undone folders)
            get_reflections_folder

            @reflections_to_calculate = n_of_reflections

            n_of_rays.times do
              @current_layer = get_layer("Direct Sound")
              viz_color = Sketchup::Color.new(255,0,0)
              @current_layer.color = viz_color

              random_starting_point = generate_random_point(@clicked_face_normal, position)
              hit_point, hit_components = shoot_ray(position, position.vector_to(random_starting_point), @current_layer)

              if hit_point.nil?
                next
              end

              # Get the normal from the hit path, properly transformed to global coordinates
              normal = get_normal_from_hit_path(hit_components)
              next if normal.nil?
              
              reflection_vector = calculate_reflection_vector(position.vector_to(hit_point), normal)
              next if reflection_vector.length < 0.001
              
              calculate_first_reflections(hit_point, n_of_rays, n_of_reflections - 1, reflection_vector)
            end

            @model.commit_operation
          else
            @current_layer = get_layer("#{@reflections_to_calculate - n_of_reflections} - Reflection")
            viz_color = Sketchup::Color.new( (255 / @reflections_to_calculate) * (n_of_reflections - 1), 0, ( 255 / @reflections_to_calculate) * n_of_reflections)
            @current_layer.color = viz_color

            hit_point, hit_components = shoot_ray(position, reflection_vector, @current_layer)

            if hit_point.nil?
              return
            end

            # Get the normal from the hit path, properly transformed to global coordinates
            normal = get_normal_from_hit_path(hit_components)
            return if normal.nil?
            
            reflection_vector = calculate_reflection_vector(position.vector_to(hit_point), normal)
            calculate_first_reflections(hit_point, n_of_rays, n_of_reflections - 1, reflection_vector)
          end
        else
          unless reflection_vector
            return
          end

          # shoot_ray(position, reflection_vector)
        end
      end

      def calculate_reflection_vector(incident_vector, normal_vector)
        incident_vector.normalize!
        dot_product = incident_vector.dot(normal_vector)

        normal_vector_dot_product = Geom::Vector3d.new(dot_product * normal_vector[0], dot_product * normal_vector[1], dot_product * normal_vector[2])
        # return:
        reflection_vector = incident_vector - normal_vector_dot_product - normal_vector_dot_product
      end

      # Get the normal from a raytest hit path, properly transformed to global coordinates
      def get_normal_from_hit_path(hit_path)
        # The last element in the path is typically the face we hit
        # The preceding elements are groups/components we passed through
        
        # Compute cumulative transformation from all parent entities
        cumulative_transform = Geom::Transformation.new
        hit_path.each do |entity|
          if entity.respond_to?(:transformation)
            cumulative_transform = cumulative_transform * entity.transformation
          end
        end
        
        # Find the face in the path
        face = hit_path.find { |e| e.is_a?(Sketchup::Face) }
        
        if face
          # Transform the face normal to global coordinates
          return face.normal.transform(cumulative_transform)
        end
        
        # If no face in path, the first entity might be a group/component
        # Try to find the face using the old method as fallback
        first_entity = hit_path[0]
        if first_entity.respond_to?(:definition)
          return find_face_in_component(hit_path)
        end
        
        nil
      end
      
      # Fallback: find face in a component hierarchy based on the hit path
      def find_face_in_component(hit_path)
        # Build cumulative transformation
        cumulative_transform = Geom::Transformation.new
        
        hit_path.each do |entity|
          next unless entity.respond_to?(:transformation)
          cumulative_transform = cumulative_transform * entity.transformation
          
          # Search for faces in this entity's definition
          faces = entity.definition.entities.grep(Sketchup::Face)
          return faces.first.normal.transform(cumulative_transform) if faces.any?
        end
        
        nil
      end

      def generate_random_point(normal, source)
        # Target - centre of the circle 1 meter away from the mouse position in the direction of the face normal
        target = source.offset(normal, 1.m)
        direction = source.vector_to(target)

        #
        tr = Geom::Transformation.new(target, direction)

        # Angle will hold a random angle in the range [0, 2π), which represents a full circle in radians
        angle = rand * 2 * Math::PI

        # Calculate a random radius "slice" in a circle with 1m radius using a uniform formula
        # http://www.anderswallin.net/2009/05/uniform-random-points-in-a-circle-using-polar-coordinates/
        random_radius = 1.m * Math.sqrt(rand)

        # Generate random 2D coordinates (x and y) that are evenly distributed around a circle with a radius of random_radius
        x = random_radius * Math.sin(angle)
        y = random_radius * Math.cos(angle)

        random_point = Geom::Point3d.new(x, y, 0)
        # Transform random_point to a new position relative to the target point and aligned with the direction vector
        random_point.transform!(tr)
      end

      def shoot_ray(source, vector, visualization_layer)
        hit = @model.raytest(source, vector) # Cast a ray through the model and return the first thing it hits
        if hit.nil?
          return
        end

        visualisation = @entities.add_cline(source, hit[0]) # Add a finite CLine from the mouse Input Point to rays first hit.
        visualisation.layer = visualization_layer

        return hit
      end

      private

      def get_reflections_folder
        # Always check if the folder still exists and is valid
        # (it may have been deleted by Undo or manually)
        begin
          if @reflections_folder && @reflections_folder.valid?
            return @reflections_folder
          end
        rescue TypeError
          # Reference was deleted
        end
        
        # Try to find existing folder
        @reflections_folder = @model.layers.folders.find { |f| f.name == "Reflections | VMFRC" }
        
        # Create if it doesn't exist
        if @reflections_folder.nil?
          @reflections_folder = @model.layers.add_folder("Reflections | VMFRC")
        end
        
        @reflections_folder
      end

      def get_layer(name)
        folder = get_reflections_folder
        current_layer = folder.layers.find { |f| f.name == name }

        if current_layer.nil?
          current_layer = @model.layers.add_layer(name)
          current_layer.folder = folder
        end
        return current_layer
      end
    end

    # Reload extension.
    #
    # @param clear_console [Boolean] Whether console should be cleared.
    # @param undo [Boolean] Whether last oration should be undone.
    #
    # @return [void]
    def self.reload(clear_console = true, undo = false)
      # Hide warnings for already defined constants.
      verbose = $VERBOSE
      $VERBOSE = nil
      begin
        # Reload the loader file
        loader = File.join(PATH_ROOT, FILENAMESPACE + '.rb')
        load(loader) if File.exist?(loader)

        # Reload all files in the plugin subfolder
        pattern = File.join(PATH, "**/*.{rb,rbe}")
        files = Dir.glob(pattern)
        files.each do |f|
          begin
            load(f)
          rescue Exception => e
            puts "Error loading #{f}: #{e.message}"
            puts e.backtrace
          end
        end
      rescue Exception => e
        puts "Error in reload: #{e.message}"
        puts e.backtrace
      ensure
        $VERBOSE = verbose
      end

      # Use a timer to make call to method itself register to console.
      # Otherwise the user cannot use up arrow to repeat command.
      UI.start_timer(0) { SKETCHUP_CONSOLE.clear } if clear_console

      Sketchup.undo if undo

      nil
    end

    def self.activate_reflections_tool
      self.capture_event('tool_activated')
      Sketchup.active_model.select_tool(FirstReflectionsTool.new)
    end

    unless file_loaded?(__FILE__)
      menu = UI.menu('Plugins')
      menu.add_item('First Reflections Tool') {
        self.activate_reflections_tool
      }
      file_loaded(__FILE__)
    end

  end
end