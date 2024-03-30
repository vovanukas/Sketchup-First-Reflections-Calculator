require 'sketchup.rb'

module VM
  module FirstReflectionsCalculator

    class FirstReflectionsTool
      # Set-up instance variables when the tool is activated
      def activate
        @mouse_ip = Sketchup::InputPoint.new # Input Point is used to pick 3d point, which reside under the cursor
        @face = nil
        @model = Sketchup.active_model # Get active model
        @entities = @model.entities # Get entities class; Needed to spawn CLines
        @reflections_folder = @model.layers.folders.find {|f| f.name == "Reflections | VMFRC" }
      end

      # Method when user presses the Left Mouse Button
      def onLButtonDown(flag, x, y, view)
        @mouse_ip.pick(view, x, y) # Pick the 3D point below the cursor

        @face = @mouse_ip.face # Get face that the cursor has been clicked on
        if @face.nil?
          UI.messagebox("Point must be on a face.")
          return
        end

        if @reflections_folder.nil?
          @reflections_folder = @model.layers.add_folder("Reflections | VMFRC")
        end

        user_input = UI.inputbox(["Number of Rays", "Number of Reflections"], [20, 2], "First Reflections Calculator")
        n_of_rays = user_input[0]
        n_of_reflections = user_input[1]

        calculate_first_reflections(@mouse_ip.position ,n_of_rays, n_of_reflections)
      end

      def calculate_first_reflections(position, n_of_rays, n_of_reflections, reflection_vector=nil)
        if n_of_reflections > 0
          if reflection_vector.nil?
            @model.start_operation('Calculate Reflections', true)
            @reflections_to_calculate = n_of_reflections

            n_of_rays.times do
              @current_layer = get_layer("Direct Sound")

              random_starting_point = generate_random_point(@face.normal, position)
              hit_point, hit_components = shoot_ray(position, position.vector_to(random_starting_point), @current_layer)

              if hit_point.nil?
                next
              end

              reflection_vector = calculate_reflection_vector(position.vector_to(hit_point), hit_components[0].normal)
              calculate_first_reflections(hit_point, n_of_rays, n_of_reflections - 1, reflection_vector)
            end

            @model.commit_operation
          else
            @current_layer = get_layer("#{@reflections_to_calculate - n_of_reflections} - Reflection")

            hit_point, hit_components = shoot_ray(position, reflection_vector, @current_layer)

            if hit_point.nil?
              return
            end

            reflection_vector = calculate_reflection_vector(position.vector_to(hit_point), hit_components[0].normal)
            # shoot_ray(hit_point, reflection_vector)
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

      # TODO: If I hit a face in a group or component, I will need to go through every face in it and find which face I hit based on the point
      def find_face_based_on_point(point, component)
        component.definition.entities.grep(Sketchup::Face) do |face|
          if face.bounds.contains?(point)
            return face.normal
          end
        end
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
          # UI.messagebox("Ray didn't hit anything.")
          return
        end

        visualisation = @entities.add_cline(source, hit[0]) # Add a finite CLine from the mouse Input Point to rays first hit.
        puts(visualization_layer.display_name)
        visualisation.layer = visualization_layer

        return hit
      end

      private

      def get_layer(name)
        current_layer = @reflections_folder.layers.find { |f| f.name == name }

        if current_layer.nil?
          current_layer = @model.layers.add_layer(name)
          current_layer.folder = @reflections_folder
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
      Dir.glob(File.join(PATH_ROOT, "**/*.{rb,rbe}")).each { |f| load(f) }
      $VERBOSE = verbose

      # Use a timer to make call to method itself register to console.
      # Otherwise the user cannot use up arrow to repeat command.
      UI.start_timer(0) { SKETCHUP_CONSOLE.clear } if clear_console

      Sketchup.undo if undo

      nil
    end

    def self.activate_reflections_tool
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