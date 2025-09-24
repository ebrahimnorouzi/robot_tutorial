# Use a fixed version so behavior is reproducible with ROBOT
FROM obolibrary/odkfull:latest

# Work in /work to match typical bind-mount usage
WORKDIR /work

# Copy scripts into the image
COPY dataset.sh /work/dataset.sh
COPY run_demo.sh /work/run_demo.sh

# Ensure Unix line endings and executable bits
RUN sed -i 's/\r$//' /work/dataset.sh /work/run_demo.sh && \
    chmod +x /work/dataset.sh /work/run_demo.sh

# Create results dir in the image (will be reused if no bind mount is provided)
RUN mkdir -p /work/results /work/data

# Default command runs both scripts
# Users can override with: docker run ... /bin/bash
CMD ["/bin/bash", "-lc", "/work/dataset.sh && /work/run_demo.sh && echo 'All done. See ./results'"]
