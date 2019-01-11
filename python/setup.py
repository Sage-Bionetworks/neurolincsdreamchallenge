from setuptools import setup

setup(name='neurolincsdreamchallenge',
      version='0.1',
      description='NeuroLINCS DREAM challenge.',
      long_description='NeuroLINCS DREAM challenge',
      url='http://github.com/Sage-Bionetworks/neurolincsdreamchallenge',
      author='Kenneth Daily',
      author_email='kenneth.daily@sagebionetworks.org',
      classifiers=[
        'Development Status :: 3 - Alpha',
        'License :: OSI Approved :: MIT License',
        'Programming Language :: Python :: 2.7',
        'Topic :: Utilities'
      ],
      license='MIT',
      packages=['neurolincsdreamchallenge'],
      install_requires=[
          'pandas',
          'synapseclient'
      ],
      scripts=['bin/get-image-layers.py'],
      zip_safe=False)
