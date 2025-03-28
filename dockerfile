# set up the base image
FROM python:3.11.9

# sets the working directory
WORKDIR /app

# copy files to current directory
COPY input.py setup.sql requirements.txt ./

# install dependencies w/ pip
RUN pip install --no-cache-dir --upgrade pip \ 
&& pip install --no-cache-dir -r requirements.txt

# run the script
CMD ["python", "input.py"]